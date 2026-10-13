import { useEffect, useState } from "react";

import { Link, useParams } from "react-router-dom";

import {
  getProduct,
  getMerchantByAuthority,
  getEscrowCreatedByDigest,
  getProductReviews,
  getProductMessages,
} from "../lib/marketplaceData";

import { useCurrentAccount, useDAppKit } from "@mysten/dapp-kit-react";

import {
  calculateOrderAmounts,
  createEscrowTx,
  createBuyerOrderTx,
  createBuyerPurchaseOfferTx,
} from "../lib/buyOrder";

import { sendProductMessageTx } from "../lib/marketplace";

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

  const [reviews, setReviews] = useState([]);

  const [loading, setLoading] = useState(true);

  const [error, setError] = useState("");

  const [selectedImageIndex, setSelectedImageIndex] = useState(0);

  const [quantity, setQuantity] = useState(1);

  const account = useCurrentAccount();

  const dAppKit = useDAppKit();

  const [buying, setBuying] = useState(false);

  const [buyMessage, setBuyMessage] = useState("");
  const [offerOpen, setOfferOpen] = useState(false);
  const [offerPrice, setOfferPrice] = useState("");
  const [offering, setOffering] = useState(false);
  const [offerMessage, setOfferMessage] = useState("");
  const [pendingOfferEscrow, setPendingOfferEscrow] = useState(null);

  const [messageSellerOpen, setMessageSellerOpen] = useState(false);

  const [sellerMessage, setSellerMessage] = useState("");

  const [sendingSellerMessage, setSendingSellerMessage] = useState(false);

  const [sellerMessageStatus, setSellerMessageStatus] = useState("");

  const [productMessages, setProductMessages] = useState([]);

  const [loadingMessages, setLoadingMessages] = useState(false);

  useEffect(() => {
    let cancelled = false;

    async function load() {
      try {
        setLoading(true);

        setError("");

        const item = await getProduct(id);

        if (cancelled) return;

        setProduct(item);

        const productReviews = await getProductReviews(item.objectId);

        if (!cancelled) {
          setReviews(productReviews);
        }

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

  useEffect(() => {
    if (product?.objectId && account?.address) {
      loadProductMessages();
    } else {
      setProductMessages([]);
    }
  }, [product?.objectId, account?.address]);

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

  const reviewCount = reviews.length;

  const reviewRatingTotal = reviews.reduce(
    (total, review) => total + Number(review.rating ?? 0),

    0,
  );

  const averageReviewRating =
    reviewCount > 0 ? reviewRatingTotal / reviewCount : 0;

  function renderReviewStars(rating) {
    const value = Number(rating ?? 0);

    return [1, 2, 3, 4, 5].map((star) => (star <= value ? "★" : "☆")).join("");
  }

  function shortAddress(address) {
    if (!address) return "Unknown buyer";

    if (address.length <= 14) {
      return address;
    }

    return `${address.slice(0, 6)}...${address.slice(-4)}`;
  }

  function formatReviewDate(timestamp) {
    if (!timestamp) return "";

    const numericTimestamp = Number(timestamp);

    if (!Number.isFinite(numericTimestamp)) {
      return "";
    }

    return new Date(numericTimestamp).toLocaleDateString();
  }

  const safeQuantity = Math.max(
    1,

    Math.min(Number(quantity) || 1, Math.max(availableStock, 1)),
  );

  let stockLabel;

  if (availableStock <= 0) {
    stockLabel = "Out of Stock";
  } else if (availableStock <= 5) {
    stockLabel = `Only ${availableStock} left`;
  } else {
    stockLabel = "In Stock";
  }

  async function loadProductMessages() {
    if (!product?.objectId || !account?.address) {
      setProductMessages([]);

      return;
    }

    try {
      setLoadingMessages(true);

      const messages = await getProductMessages(
        product.objectId,

        account.address,
      );

      setProductMessages(messages);
    } catch (error) {
      console.error("Load product messages error:", error);
    } finally {
      setLoadingMessages(false);
    }
  }

  async function sendMessageToSeller() {
    if (!account?.address) {
      setSellerMessageStatus("Connect your wallet first.");

      return;
    }

    if (!merchant?.authority) {
      setSellerMessageStatus("Seller information is unavailable.");

      return;
    }

    if (account.address.toLowerCase() === merchant.authority.toLowerCase()) {
      setSellerMessageStatus("You cannot message yourself as a buyer.");

      return;
    }

    const text = sellerMessage.trim();

    if (!text) {
      setSellerMessageStatus("Enter a message.");

      return;
    }

    if (new TextEncoder().encode(text).length > 280) {
      setSellerMessageStatus("Message must be 280 bytes or less.");

      return;
    }

    try {
      setSendingSellerMessage(true);

      setSellerMessageStatus("");

      const tx = sendProductMessageTx({
        productId: product.objectId,

        buyer: account.address,

        message: text,
      });

      const result = await dAppKit.signAndExecuteTransaction({
        transaction: tx,
      });

      if (result.FailedTransaction) {
        throw new Error(
          result.FailedTransaction.status?.error?.message ||
            "Failed to send message.",
        );
      }

      const digest = result.Transaction.digest;

      console.log("Message transaction:", digest);

      setSellerMessage("");

      setSellerMessageStatus(`Message sent successfully. ${digest}`);

      await loadProductMessages();
    } catch (error) {
      console.error("Send message error:", error);

      setSellerMessageStatus(error?.message || "Failed to send message.");
    } finally {
      setSendingSellerMessage(false);
    }
  }

  // Parse SUI decimals exactly; never use floating-point for token amounts.
  function parseSuiMist(input) {
    const value = String(input).trim();
    if (!/^(?:0|[1-9]\d*)(?:\.\d{1,9})?$/.test(value)) {
      throw new Error("Enter a valid SUI price (up to 9 decimal places).");
    }
    const [whole, fraction = ""] = value.split(".");
    const mist =
      BigInt(whole) * 1_000_000_000n + BigInt(fraction.padEnd(9, "0") || "0");
    if (mist <= 0n || mist > 18446744073709551615n) {
      throw new Error("Offer price is outside the allowed range.");
    }
    return mist;
  }

  async function makeOffer() {
    if (!account?.address || !merchant?.authority) {
      setOfferMessage("Connect your wallet and load seller details first.");
      return;
    }
    if (account.address.toLowerCase() === merchant.authority.toLowerCase()) {
      setOfferMessage("You cannot offer on your own product.");
      return;
    }
    if (safeQuantity < 1 || safeQuantity > availableStock) {
      setOfferMessage("Invalid quantity or insufficient stock.");
      return;
    }
    try {
      setOffering(true);
      setOfferMessage("");
      const unitPriceMist = parseSuiMist(offerPrice);
      const amounts = calculateOrderAmounts({
        price: unitPriceMist,
        quantity: safeQuantity,
        sellerDepositBps: merchant.seller_deposit_bps,
      });
      const offerKey = [
        account.address,
        merchant.authority,
        product.objectId,
        unitPriceMist.toString(),
        String(safeQuantity),
      ].join(":");
      // If an escrow was created but step 2 failed, keep its ID and allow retry.
      // A retry must use the original price, quantity, and escrow.
      let pending = pendingOfferEscrow;
      if (pending && pending.key !== offerKey && !pending.retryable)
        pending = null;
      if (pending && pending.retryable) {
        if (
          pending.buyer !== account.address ||
          pending.productId !== product.objectId ||
          pending.unitPrice !== unitPriceMist.toString() ||
          pending.quantity !== safeQuantity
        ) {
          throw new Error(
            "An earlier escrow needs recovery. Restore the original price and quantity before retrying.",
          );
        }
      } else {
        setOfferMessage("Step 1 of 2: Creating escrow...");
        const tx = createEscrowTx({
          buyer: account.address,
          seller: merchant.authority,
          totalPrice: amounts.totalPrice,
          buyerDeposit: amounts.buyerDeposit,
          securityDeposit: amounts.securityDeposit,
          productId: product.objectId,
        });
        const result = await dAppKit.signAndExecuteTransaction({
          transaction: tx,
        });
        if (result.FailedTransaction) {
          throw new Error(
            result.FailedTransaction.status?.error?.message ||
              "Escrow creation failed.",
          );
        }
        const digest = result.Transaction.digest;
        let escrowId = null;
        for (let attempt = 0; attempt < 10; attempt++) {
          try {
            escrowId = await getEscrowCreatedByDigest(digest);
          } catch {
            /* retry */
          }
          if (escrowId) break;
          await new Promise((resolve) => setTimeout(resolve, 700));
        }
        if (!escrowId) {
          throw new Error(
            `Escrow created in transaction ${digest}, but its ID could not be indexed yet. Do not resubmit until recovered.`,
          );
        }
        pending = {
          key: offerKey,
          retryable: true,
          escrowId,
          buyer: account.address,
          productId: product.objectId,
          unitPrice: unitPriceMist.toString(),
          quantity: safeQuantity,
          buyerDeposit: amounts.buyerDeposit.toString(),
        };
        setPendingOfferEscrow(pending);
      }
      setOfferMessage("Step 2 of 2: Locking funds and submitting offer...");
      const offerTx = createBuyerPurchaseOfferTx({
        escrowId: pending.escrowId,
        merchantId: merchant.objectId,
        productId: product.objectId,
        unitPriceMist: BigInt(pending.unitPrice),
        quantity: pending.quantity,
        buyerDeposit: BigInt(pending.buyerDeposit),
      });
      const result = await dAppKit.signAndExecuteTransaction({
        transaction: offerTx,
      });
      if (result.FailedTransaction) {
        throw new Error(
          result.FailedTransaction.status?.error?.message ||
            "Offer submission failed.",
        );
      }
      setPendingOfferEscrow(null);
      setOfferOpen(false);
      setOfferMessage(
        `Offer submitted successfully. Transaction: ${result.Transaction.digest}`,
      );
    } catch (err) {
      setOfferMessage(err?.message || "Failed to submit offer.");
    } finally {
      setOffering(false);
    }
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
            "Failed to create escrow.",
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
          "Escrow was created, but the escrow object ID could not be found.",
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
            "Failed to create order.",
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
                          current === 0
                            ? productImages.length - 1
                            : current - 1,
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
                          current === productImages.length - 1
                            ? 0
                            : current + 1,
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

            <div className="product-sub-info">
              {soldCount} sold
              {reviewCount > 0 && (
                <>
                  {" · "}
                  <span className="product-rating-stars">★</span>{" "}
                  <strong>{averageReviewRating.toFixed(1)}</strong>
                  {" · "}
                  {reviewCount} {reviewCount === 1 ? "review" : "reviews"}
                </>
              )}
            </div>

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

            <div className="product-action-buttons">
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

              <button
                type="button"
                className="product-message-button"
                onClick={() => {
                  setOfferOpen((open) => !open);
                  setOfferMessage("");
                }}
                disabled={buying || offering || availableStock <= 0}
              >
                {offerOpen ? "Close Offer" : "Make Offer"}
              </button>
            </div>

            {offerOpen && (
              <div className="product-offer-form">
                <h3>Make a Price Offer</h3>
                <label htmlFor="offer-price">Offer per item (SUI)</label>
                <input
                  id="offer-price"
                  type="text"
                  inputMode="decimal"
                  placeholder="e.g. 0.85"
                  value={offerPrice}
                  onChange={(e) => setOfferPrice(e.target.value)}
                  disabled={offering}
                />
                <p>
                  Quantity: {safeQuantity}. Your offered price plus the required
                  security deposit will be locked in escrow before the seller
                  accepts.
                </p>
                <button
                  type="button"
                  className="product-buy-button"
                  onClick={makeOffer}
                  disabled={offering || buying || !offerPrice.trim()}
                >
                  {offering ? "Submitting Offer..." : "Confirm & Fund Offer"}
                </button>
              </div>
            )}
            {offerMessage && (
              <div className="product-buy-message">{offerMessage}</div>
            )}
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
                {account?.address?.toLowerCase() !==
                  merchant.authority?.toLowerCase() && (
                  <button
                    type="button"
                    className="product-message-button"
                    onClick={() => {
                      setMessageSellerOpen((open) => !open);
                      setSellerMessageStatus("");
                    }}
                  >
                    {messageSellerOpen ? "Close Message" : "Message Seller"}
                  </button>
                )}

                {account?.address?.toLowerCase() !==
                  merchant.authority?.toLowerCase() && (
                  <>
                    {messageSellerOpen && (
                      <div className="seller-message-box">
                        <div className="seller-conversation">
                          {loadingMessages ? (
                            <p>Loading messages...</p>
                          ) : productMessages.length === 0 ? (
                            <p>
                              No messages yet. Start a conversation with the
                              seller.
                            </p>
                          ) : (
                            productMessages.map((message) => {
                              const mine =
                                message.sender?.toLowerCase() ===
                                account?.address?.toLowerCase();

                              return (
                                <div
                                  key={message.objectId}
                                  className={
                                    mine
                                      ? "seller-chat-message mine"
                                      : "seller-chat-message theirs"
                                  }
                                >
                                  <strong>{mine ? "You" : "Seller"}</strong>

                                  <p>{message.message}</p>

                                  <small>
                                    {message.created_at
                                      ? new Date(
                                          Number(message.created_at),
                                        ).toLocaleString()
                                      : ""}
                                  </small>
                                </div>
                              );
                            })
                          )}
                        </div>

                        <textarea
                          value={sellerMessage}
                          maxLength={280}
                          placeholder="Ask the seller about this product..."
                          onChange={(event) =>
                            setSellerMessage(event.target.value)
                          }
                          disabled={sendingSellerMessage}
                        />

                        <div className="seller-message-count">
                          {new TextEncoder().encode(sellerMessage).length} / 280
                          bytes
                        </div>

                        <button
                          type="button"
                          onClick={sendMessageToSeller}
                          disabled={
                            sendingSellerMessage || !sellerMessage.trim()
                          }
                        >
                          {sendingSellerMessage ? "Sending..." : "Send Message"}
                        </button>

                        {sellerMessageStatus && (
                          <div className="seller-message-status">
                            {sellerMessageStatus}
                          </div>
                        )}
                      </div>
                    )}
                  </>
                )}
              </>
            ) : (
              <p className="product-muted">
                Seller information is unavailable.
              </p>
            )}
          </section>
        </div>

        <section className="product-detail-card product-section product-reviews-section">
          <div className="product-reviews-header">
            <div>
              <h2>Customer Reviews</h2>

              {reviewCount > 0 && (
                <div className="product-reviews-summary">
                  <span className="product-reviews-summary-stars">
                    {renderReviewStars(Math.round(averageReviewRating))}
                  </span>

                  <strong>{averageReviewRating.toFixed(1)}</strong>

                  <span>
                    {reviewCount} {reviewCount === 1 ? "review" : "reviews"}
                  </span>
                </div>
              )}
            </div>
          </div>

          {reviewCount === 0 ? (
            <div className="product-no-reviews">
              <div className="product-no-reviews-stars">☆☆☆☆☆</div>

              <strong>No reviews yet</strong>

              <p>Reviews from verified purchases will appear here.</p>
            </div>
          ) : (
            <div className="product-review-list">
              {reviews.map((review) => (
                <article key={review.objectId} className="product-review-item">
                  <div className="product-review-top">
                    <div>
                      <div className="product-review-stars">
                        {renderReviewStars(Number(review.rating))}
                      </div>

                      <strong className="product-review-score">
                        {Number(review.rating)} / 5
                      </strong>
                    </div>

                    <span className="product-review-verified">
                      ✓ Verified Purchase
                    </span>
                  </div>

                  {review.comment && (
                    <p className="product-review-text">{review.comment}</p>
                  )}

                  <div className="product-review-meta">
                    <span>Buyer {shortAddress(review.reviewer)}</span>

                    {review.created_at && (
                      <span>{formatReviewDate(review.created_at)}</span>
                    )}
                  </div>
                </article>
              ))}
            </div>
          )}
        </section>
      </div>
    </main>
  );
}
