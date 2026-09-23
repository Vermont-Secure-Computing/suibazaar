import { useEffect, useState } from "react";
import { Link, useParams } from "react-router-dom";

import {
  getProduct,
  getMerchantByAuthority,
  getEscrowCreatedByDigest,
} from "../lib/marketplaceData";

import { useCurrentAccount, useDAppKit } from "@mysten/dapp-kit-react";

import {
  calculateOrderAmounts,
  createEscrowTx,
  createBuyerOrderTx,
} from "../lib/buyOrder";

import "./ProductPage.css";

function formatSui(mist) {
  try {
    const value = BigInt(mist ?? 0);

    const whole = value / 1_000_000_000n;
    const fraction = value % 1_000_000_000n;

    const fractionText = fraction
      .toString()
      .padStart(9, "0")
      .replace(/0+$/, "");

    return fractionText ? `${whole}.${fractionText}` : whole.toString();
  } catch {
    return "0";
  }
}

export default function ProductPage() {
  const { id } = useParams();

  const [product, setProduct] = useState(null);
  const [merchant, setMerchant] = useState(null);

  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  const [selectedImageIndex, setSelectedImageIndex] = useState(0);

  const [quantity, setQuantity] = useState(1);

  const account = useCurrentAccount();
  const dAppKit = useDAppKit();

  const [buying, setBuying] = useState(false);

  const [buyMessage, setBuyMessage] = useState("");

  useEffect(() => {
    let cancelled = false;

    async function load() {
      try {
        setLoading(true);
        setError("");

        const item = await getProduct(id);

        if (cancelled) return;

        setProduct(item);

        if (item.merchant) {
          const seller = await getMerchantByAuthority(item.merchant);

          if (!cancelled) {
            setMerchant(seller);
          }
        }
      } catch (err) {
        console.error("Load product error:", err);

        if (!cancelled) {
          setError(err?.message || "Failed to load product.");
        }
      } finally {
        if (!cancelled) {
          setLoading(false);
        }
      }
    }

    if (id) {
      load();
    }

    return () => {
      cancelled = true;
    };
  }, [id]);

  if (loading) {
    return (
      <main className="product-page">
        <div className="product-shell">
          <p>Loading product...</p>
        </div>
      </main>
    );
  }

  if (error) {
    return (
      <main className="product-page">
        <div className="product-shell">
          <Link to="/" className="product-back">
            ← Back to Marketplace
          </Link>

          <div className="product-error">{error}</div>
        </div>
      </main>
    );
  }

  if (!product) {
    return (
      <main className="product-page">
        <div className="product-shell">
          <p>Product not found.</p>
        </div>
      </main>
    );
  }

  const productImages = product.image_uris?.filter(Boolean) ?? [];

  const selectedImage = productImages[selectedImageIndex] ?? "";

  const availableStock = Number(product.stock ?? 0);

  const soldCount = Number(product.sold ?? 0);

  const safeQuantity = Math.max(
    1,
    Math.min(Number(quantity) || 1, Math.max(availableStock, 1))
  );

  let stockLabel;

  if (availableStock <= 0) {
    stockLabel = "Out of Stock";
  } else if (availableStock <= 5) {
    stockLabel = `Only ${availableStock} left`;
  } else {
    stockLabel = "In Stock";
  }

  async function buyNow() {
    if (!account?.address) {
      setBuyMessage("Connect your wallet first.");
      return;
    }

    if (!merchant) {
      setBuyMessage("Seller information is unavailable.");
      return;
    }

    if (account.address.toLowerCase() === merchant.authority.toLowerCase()) {
      setBuyMessage("You cannot buy your own product.");
      return;
    }

    if (
      !Number.isInteger(safeQuantity) ||
      safeQuantity < 1 ||
      safeQuantity > availableStock
    ) {
      setBuyMessage("Invalid quantity.");
      return;
    }

    try {
      setBuying(true);
      setBuyMessage("");

      const amounts = calculateOrderAmounts({
        price: product.price,
        quantity: safeQuantity,
        sellerDepositBps: merchant.seller_deposit_bps,
      });

      /*
       * ==========================
       * TRANSACTION 1
       * Create shared escrow
       * ==========================
       */

      setBuyMessage("Step 1 of 2: Create escrow...");

      const escrowTx = createEscrowTx({
        buyer: account.address,
        seller: merchant.authority,

        totalPrice: amounts.totalPrice,

        buyerDeposit: amounts.buyerDeposit,

        securityDeposit: amounts.securityDeposit,

        productId: product.objectId,
      });

      const escrowResult = await dAppKit.signAndExecuteTransaction({
        transaction: escrowTx,
      });

      if (escrowResult.FailedTransaction) {
        throw new Error(
          escrowResult.FailedTransaction.status?.error?.message ||
            "Failed to create escrow."
        );
      }

      const escrowDigest = escrowResult.Transaction.digest;

      /*
       * Find the newly-created shared
       * Escrow object.
       */
      setBuyMessage("Escrow created. Preparing order...");

      let escrowId = null;

      /*
       * Event indexing can take a moment,
       * so retry a few times.
       */
      for (let attempt = 0; attempt < 10; attempt++) {
        try {
          escrowId = await getEscrowCreatedByDigest(escrowDigest);

          if (escrowId) {
            break;
          }
        } catch {
          // wait below
        }

        await new Promise((resolve) => setTimeout(resolve, 700));
      }

      if (!escrowId) {
        throw new Error(
          "Escrow was created, but the escrow object ID could not be found."
        );
      }

      console.log("Created escrow:", escrowId);

      /*
       * ==========================
       * TRANSACTION 2
       *
       * Buyer deposits:
       * product total + deposit
       *
       * Then create_order_record()
       * reserves stock.
       * ==========================
       */

      setBuyMessage("Step 2 of 2: Deposit funds and create order...");

      const orderTx = createBuyerOrderTx({
        escrowId,

        merchantId: merchant.objectId,

        productId: product.objectId,

        quantity: safeQuantity,

        buyerDeposit: amounts.buyerDeposit,
      });

      const orderResult = await dAppKit.signAndExecuteTransaction({
        transaction: orderTx,
      });

      if (orderResult.FailedTransaction) {
        throw new Error(
          orderResult.FailedTransaction.status?.error?.message ||
            "Failed to create order."
        );
      }

      const orderDigest = orderResult.Transaction.digest;

      console.log("Order transaction:", orderDigest);

      setBuyMessage(`Order created successfully. ${orderDigest}`);

      /*
       * Refresh product so reserved stock
       * immediately updates.
       */
      const updatedProduct = await getProduct(product.objectId);

      setProduct(updatedProduct);
    } catch (error) {
      console.error("Buy error:", error);

      setBuyMessage(error?.message || "Failed to create order.");
    } finally {
      setBuying(false);
    }
  }

  return (
    <main className="product-page">
      <div className="product-shell">
        <Link to="/" className="product-back">
          ← Back to Marketplace
        </Link>

        <div className="product-layout">
          {/* IMAGE GALLERY */}

          <section>
            <div className="product-detail-card">
              <div className="product-image-wrap">
                {soldCount > 0 && (
                  <span className="product-sold-badge">{soldCount} sold</span>
                )}

                {selectedImage ? (
                  <img
                    src={selectedImage}
                    alt={`${product.title} image ${selectedImageIndex + 1}`}
                    className="product-main-image"
                  />
                ) : (
                  <div className="product-no-image-detail">
                    No product image
                  </div>
                )}

                {productImages.length > 1 && (
                  <>
                    <button
                      type="button"
                      className="product-gallery-arrow previous"
                      onClick={() =>
                        setSelectedImageIndex((current) =>
                          current === 0 ? productImages.length - 1 : current - 1
                        )
                      }
                    >
                      ‹
                    </button>

                    <button
                      type="button"
                      className="product-gallery-arrow next"
                      onClick={() =>
                        setSelectedImageIndex((current) =>
                          current === productImages.length - 1 ? 0 : current + 1
                        )
                      }
                    >
                      ›
                    </button>

                    <span className="product-image-counter">
                      {selectedImageIndex + 1} / {productImages.length}
                    </span>
                  </>
                )}
              </div>
            </div>

            {productImages.length > 1 && (
              <div className="product-thumbnails">
                {productImages.map((imageUri, index) => (
                  <button
                    key={`${imageUri}-${index}`}
                    type="button"
                    className={
                      "product-thumbnail " +
                      (selectedImageIndex === index ? "active" : "")
                    }
                    onClick={() => setSelectedImageIndex(index)}
                  >
                    <img
                      src={imageUri}
                      alt={`${product.title} thumbnail ${index + 1}`}
                    />
                  </button>
                ))}
              </div>
            )}
          </section>

          {/* PURCHASE PANEL */}

          <aside className="product-detail-card product-purchase">
            <div className="product-badges">
              <span
                className={
                  "product-badge " +
                  (availableStock <= 0
                    ? "out"
                    : availableStock <= 5
                    ? "low"
                    : "stock")
                }
              >
                {stockLabel}
              </span>

              {merchant?.ships_from && (
                <span className="product-badge shipping">
                  Ships from {merchant.ships_from}
                </span>
              )}
            </div>

            <h1 className="product-title">{product.title}</h1>

            <div className="product-sub-info">{soldCount} sold</div>

            <h2 className="product-detail-price">
              {formatSui(product.price)} SUI
            </h2>

            <p className="product-muted">Price per item</p>

            <div className="product-meta">
              <div className="product-meta-item">
                <span>Category</span>

                <strong>{product.category || "Uncategorized"}</strong>
              </div>

              <div className="product-meta-item">
                <span>Stock</span>

                <strong>
                  {availableStock} {availableStock === 1 ? "item" : "items"}
                </strong>
              </div>
            </div>

            {availableStock > 0 && (
              <div className="product-quantity">
                <div>
                  <strong>Quantity</strong>

                  <div className="product-available">
                    {availableStock} available
                  </div>
                </div>

                <div className="quantity-controls">
                  <button
                    type="button"
                    disabled={safeQuantity <= 1}
                    onClick={() => setQuantity(Math.max(1, safeQuantity - 1))}
                  >
                    −
                  </button>

                  <input
                    type="number"
                    min="1"
                    max={availableStock}
                    value={quantity}
                    onChange={(event) => {
                      const value = event.target.value;

                      if (value === "") {
                        setQuantity("");
                        return;
                      }

                      setQuantity(Number(value));
                    }}
                  />

                  <button
                    type="button"
                    disabled={safeQuantity >= availableStock}
                    onClick={() =>
                      setQuantity(Math.min(availableStock, safeQuantity + 1))
                    }
                  >
                    +
                  </button>
                </div>
              </div>
            )}

            <div className="product-total">
              <span>
                {safeQuantity > 1 ? `Total (${safeQuantity} items)` : "Total"}
              </span>

              <strong>
                {formatSui(BigInt(product.price ?? 0) * BigInt(safeQuantity))}{" "}
                SUI
              </strong>
            </div>

            <button
              type="button"
              className="product-buy-button"
              onClick={buyNow}
              disabled={buying || availableStock <= 0}
            >
              {availableStock <= 0
                ? "Out of Stock"
                : buying
                ? "Processing..."
                : `Buy ${safeQuantity} ${
                    safeQuantity === 1 ? "Item" : "Items"
                  }`}
            </button>

            {availableStock > 0 && (
              <p className="product-buy-note">
                Secure purchase with Sui escrow
              </p>
            )}

            {buyMessage && (
              <div className="product-buy-message">{buyMessage}</div>
            )}
          </aside>
        </div>

        {/* DESCRIPTION + SELLER */}

        <div className="product-details-grid">
          <section className="product-detail-card product-section">
            <h2>Description</h2>

            <p className="product-description-detail">
              {product.description_uri || "No description provided."}
            </p>
          </section>

          <section className="product-detail-card product-section">
            <h2>Sold by</h2>

            {merchant ? (
              <>
                <div className="seller-header">
                  <div className="seller-avatar">
                    {(merchant.store_name || "S").slice(0, 1).toUpperCase()}
                  </div>

                  <div>
                    <strong className="seller-name">
                      {merchant.store_name}
                    </strong>

                    {merchant.verified && (
                      <div className="seller-verified">Verified</div>
                    )}
                  </div>
                </div>

                <div className="seller-stats">
                  <div>
                    <strong>{Number(merchant.total_sold ?? 0)}</strong>

                    <span>Sold</span>
                  </div>

                  <div>
                    <strong>{merchant.ships_from || "—"}</strong>

                    <span>Ships from</span>
                  </div>
                </div>

                <Link
                  to={`/merchant/${merchant.objectId}`}
                  className="seller-visit-link"
                >
                  Visit Store
                </Link>
              </>
            ) : (
              <p className="product-muted">
                Seller information is unavailable.
              </p>
            )}
          </section>
        </div>
      </div>
    </main>
  );
}
