import { useEffect, useState } from "react";

import { useNavigate } from "react-router-dom";

import { useCurrentAccount, useDAppKit } from "@mysten/dapp-kit-react";
import { acceptPurchaseOfferTx } from "../lib/acceptPurchaseOffer";
import {
  rejectPurchaseOfferTx,
  withdrawAndRefundPurchaseOfferTx,
  refundRejectedPurchaseOfferTx,
} from "../lib/purchaseOfferActions";

import {
  getBuyerOrderRecords,
  getSellerOrderRecords,
  getProduct,
  getMerchants,
  getPurchaseOffers,
} from "../lib/marketplaceData";

import {
  getMarketplaceEscrow,
  getEscrowStatusLabel,
  ESCROW_STATUS,
} from "../lib/escrow";

import "./OrdersPage.css";

const MIST_PER_SUI = 1_000_000_000n;

function mistToSui(value) {
  try {
    const mist = BigInt(value ?? 0);

    const whole = mist / MIST_PER_SUI;

    const fraction = mist % MIST_PER_SUI;

    return `${whole}.${fraction

      .toString()

      .padStart(9, "0")

      .slice(0, 4)}`;
  } catch {
    return "0.0000";
  }
}

function shortenAddress(address) {
  if (!address) return "Address unavailable";

  if (address.length <= 16) {
    return address;
  }

  return `${address.slice(0, 8)}...${address.slice(-6)}`;
}

function getProductImage(product) {
  const images = product?.image_uris ?? product?.imageUris ?? [];

  if (!Array.isArray(images)) {
    return "";
  }

  return images[0] ?? "";
}

export default function OrdersPage() {
  const account = useCurrentAccount();
  const dAppKit = useDAppKit();
  const [processingOfferId, setProcessingOfferId] = useState(null);
  const [offerMessage, setOfferMessage] = useState("");

  const navigate = useNavigate();

  const [buyerOrders, setBuyerOrders] = useState([]);

  const [sellerOrders, setSellerOrders] = useState([]);

  const [buyerOffers, setBuyerOffers] = useState([]);
  const [sellerOffers, setSellerOffers] = useState([]);

  const [loading, setLoading] = useState(true);

  const [error, setError] = useState("");

  const enrichOrders = async (
    records,

    merchants
  ) => {
    return Promise.all(
      records.map(async (record) => {
        let escrow = null;

        let product = null;

        try {
          escrow = await getMarketplaceEscrow(record.escrow);
        } catch (escrowError) {
          console.error(
            "Escrow lookup error:",

            escrowError
          );
        }

        try {
          product = await getProduct(record.product);
        } catch (productError) {
          console.error(
            "Product lookup error:",

            productError
          );
        }

        const sellerMerchant =
          merchants.find(
            (merchant) =>
              merchant.authority?.toLowerCase() === record.seller?.toLowerCase()
          ) ?? null;

        return {
          ...record,

          escrow,

          product,

          sellerMerchant,
        };
      })
    );
  };

  const acceptOffer = async (offer) => {
    if (
      !account?.address ||
      offer.seller?.toLowerCase() !== account.address.toLowerCase()
    ) {
      setError("Only the seller can accept this offer.");
      return;
    }
    if (
      !offer.active ||
      offer.accepted ||
      offer.rejected ||
      offer.withdrawn ||
      Number(offer.expires_at) <= Date.now()
    ) {
      setError("This offer is no longer available for acceptance.");
      return;
    }
    const merchant = await getMerchantForOffer(offer);
    if (!merchant?.objectId) {
      setError("Merchant profile could not be resolved for this offer.");
      return;
    }
    if (
      !window.confirm(
        `Accept offer of ${mistToSui(
          offer.total_price
        )} SUI?\n\nThis reserves product stock and creates an order. The seller escrow deposit is a separate step.`
      )
    )
      return;
    try {
      setProcessingOfferId(offer.objectId);
      setError("");
      setOfferMessage("");
      const transaction = acceptPurchaseOfferTx({
        merchantId: merchant.objectId,
        productId: offer.product,
        offerId: offer.objectId,
        escrowId: offer.escrow,
      });
      const result = await dAppKit.signAndExecuteTransaction({ transaction });
      if (result.FailedTransaction) {
        throw new Error(
          result.FailedTransaction.status?.error?.message ||
            "Offer acceptance failed."
        );
      }
      setOfferMessage(
        "Offer accepted. The order should now appear in Seller Orders and My Purchases. Refresh if indexing is delayed."
      );
      await loadOrders();
    } catch (err) {
      console.error("Accept purchase offer error:", err);
      setError(err?.message || "Failed to accept offer.");
    } finally {
      setProcessingOfferId(null);
    }
  };

  const executeOfferAction = async (offer, action) => {
    if (!account?.address) {
      setError("Please connect your wallet.");
      return;
    }

    if (processingOfferId) return;

    const wallet = account.address.toLowerCase();
    const isBuyer = offer.buyer?.toLowerCase() === wallet;
    const isSeller = offer.seller?.toLowerCase() === wallet;
    const pending =
      offer.active &&
      !offer.accepted &&
      !offer.rejected &&
      !offer.withdrawn &&
      Number(offer.expires_at) > Date.now();

    let transaction;
    let confirmation;
    let successMessage;

    if (action === "reject") {
      if (!isSeller || !pending) {
        setError("Only the seller can reject a pending offer.");
        return;
      }

      confirmation = "Reject this purchase offer?";
      transaction = rejectPurchaseOfferTx({
        offerId: offer.objectId,
      });
      successMessage = "Offer rejected. Buyer may now claim the escrow refund.";
    } else if (action === "withdraw") {
      if (!isBuyer || !pending) {
        setError("Only the buyer can withdraw a pending offer.");
        return;
      }

      confirmation = "Withdraw this offer and refund your escrow deposit?";
      transaction = withdrawAndRefundPurchaseOfferTx({
        offerId: offer.objectId,
        escrowId: offer.escrow,
      });
      successMessage = "Offer withdrawn and refund transaction completed.";
    } else if (action === "refund") {
      if (!isBuyer || !offer.rejected || offer.accepted) {
        setError("This offer is not eligible for a rejected-offer refund.");
        return;
      }

      confirmation = "Claim your escrow refund?";
      transaction = refundRejectedPurchaseOfferTx({
        escrowId: offer.escrow,
      });
      successMessage = "Refund transaction completed.";
    } else {
      return;
    }

    if (!window.confirm(confirmation)) return;

    try {
      setProcessingOfferId(offer.objectId);
      setError("");
      setOfferMessage("");

      const result = await dAppKit.signAndExecuteTransaction({
        transaction,
      });

      if (result.FailedTransaction) {
        throw new Error(
          result.FailedTransaction.status?.error?.message ||
            "Transaction failed."
        );
      }

      setOfferMessage(successMessage);
      await loadOrders();
    } catch (err) {
      console.error(`Purchase offer ${action} failed:`, err);
      setError(err?.message || `${action} failed.`);
    } finally {
      setProcessingOfferId(null);
    }
  };

  const getMerchantForOffer = async (offer) => {
    const merchants = await getMerchants();
    return (
      merchants.find(
        (merchant) =>
          merchant.authority?.toLowerCase() === offer.seller?.toLowerCase()
      ) ?? null
    );
  };

  const loadOrders = async () => {
    if (!account?.address) {
      setBuyerOrders([]);

      setSellerOrders([]);
      setBuyerOffers([]);
      setSellerOffers([]);

      setLoading(false);

      return;
    }

    try {
      setLoading(true);

      setError("");

      const [buyerRecords, sellerRecords, merchants, offers] =
        await Promise.all([
          getBuyerOrderRecords(account.address),

          getSellerOrderRecords(account.address),

          getMerchants(),
          getPurchaseOffers(),
        ]);

      const [enrichedBuyer, enrichedSeller] = await Promise.all([
        enrichOrders(
          buyerRecords,

          merchants
        ),

        enrichOrders(
          sellerRecords,

          merchants
        ),
      ]);

      setBuyerOrders(enrichedBuyer);

      setSellerOrders(enrichedSeller);
      const address = account.address.toLowerCase();
      setBuyerOffers(
        offers.filter((offer) => offer.buyer?.toLowerCase() === address)
      );
      setSellerOffers(
        offers.filter((offer) => offer.seller?.toLowerCase() === address)
      );
    } catch (loadError) {
      console.error(
        "Load orders error:",

        loadError
      );

      setError(loadError?.message || "Failed to load orders.");
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadOrders();
  }, [account?.address]);

  if (!account?.address) {
    return (
      <main className="orders-page">
        <header className="orders-header">
          <h1>Orders</h1>
        </header>

        <div className="orders-state">
          Connect your wallet to view your purchases and seller orders.
        </div>
      </main>
    );
  }

  if (loading) {
    return (
      <main className="orders-page">
        <header className="orders-header">
          <h1>Orders</h1>
        </header>

        <div className="orders-state">Loading orders...</div>
      </main>
    );
  }

  return (
    <main className="orders-page">
      <header className="orders-header">
        <div>
          <h1>Orders</h1>

          <p>Manage your purchases and seller transactions.</p>
        </div>

        <button
          type="button"
          className="orders-refresh-button"
          onClick={loadOrders}
        >
          Refresh Orders
        </button>
      </header>

      {offerMessage && (
        <div className="orders-state" role="status">
          {offerMessage}
        </div>
      )}
      {error && <div className="orders-error">{error}</div>}

      <section className="orders-section">
        <h2>
          My Purchases
          <span className="orders-count">{buyerOrders.length}</span>
        </h2>

        <OrderList
          orders={buyerOrders}
          role="buyer"
          onSelect={(order) =>
            navigate(`/orders/buyer/${order.escrow?.objectId ?? order.escrow}`)
          }
        />
      </section>

      <section className="orders-section">
        <h2>
          Seller Orders
          <span className="orders-count">{sellerOrders.length}</span>
        </h2>

        <OrderList
          orders={sellerOrders}
          role="seller"
          onSelect={(order) =>
            navigate(`/orders/seller/${order.escrow?.objectId ?? order.escrow}`)
          }
        />
      </section>

      <section className="orders-section">
        <h2>
          My Offers <span className="orders-count">{buyerOffers.length}</span>
        </h2>

        <PurchaseOfferList
          offers={buyerOffers}
          role="buyer"
          onAction={executeOfferAction}
          processingOfferId={processingOfferId}
        />
      </section>

      <section className="orders-section">
        <h2>
          Received Offers{" "}
          <span className="orders-count">{sellerOffers.length}</span>
        </h2>

        <PurchaseOfferList
          offers={sellerOffers}
          role="seller"
          onAccept={acceptOffer}
          onAction={executeOfferAction}
          processingOfferId={processingOfferId}
        />
      </section>
    </main>
  );
}

function OrderList({
  orders,

  role,

  onSelect,
}) {
  const [filter, setFilter] = useState("all");

  const filteredOrders = orders.filter((order) => {
    const status = order.escrow?.status;

    if (filter === "active") {
      return (
        status !== ESCROW_STATUS.COMPLETED && status !== ESCROW_STATUS.CANCELLED
      );
    }

    if (filter === "completed") {
      return status === ESCROW_STATUS.COMPLETED;
    }

    if (filter === "needs-action") {
      if (role === "seller") {
        return (
          status === ESCROW_STATUS.CREATED &&
          BigInt(order.escrow?.depositedA ?? 0) > 0n &&
          BigInt(order.escrow?.depositedB ?? 0) === 0n
        );
      }

      if (role === "buyer") {
        return status === ESCROW_STATUS.FINALIZATION_SUGGESTED;
      }
    }

    return true;
  });

  if (orders.length === 0) {
    return (
      <div className="orders-empty">
        {role === "buyer" ? "No purchase orders yet." : "No seller orders yet."}
      </div>
    );
  }

  return (
    <>
      <div className="orders-controls">
        <label>
          Filter
          <select
            value={filter}
            onChange={(event) => setFilter(event.target.value)}
          >
            <option value="all">All Orders</option>

            <option value="needs-action">Needs Action</option>

            <option value="active">Active</option>

            <option value="completed">Completed</option>
          </select>
        </label>
      </div>

      {filteredOrders.length === 0 ? (
        <div className="orders-empty">No matching orders.</div>
      ) : (
        <div className="orders-list">
          {filteredOrders.map((order) => (
            <OrderRow
              key={order.objectId}
              order={order}
              role={role}
              onSelect={() => onSelect(order)}
            />
          ))}
        </div>
      )}
    </>
  );
}

function OrderRow({
  order,

  role,

  onSelect,
}) {
  const escrow = order.escrow;

  const product = order.product;

  const merchant = order.sellerMerchant;

  const image = getProductImage(product);

  const status = escrow?.status ?? -1;

  let needsAction = false;

  if (role === "seller") {
    needsAction =
      status === ESCROW_STATUS.CREATED &&
      BigInt(escrow?.depositedA ?? 0) > 0n &&
      BigInt(escrow?.depositedB ?? 0) === 0n;
  }

  if (role === "buyer") {
    needsAction = status === ESCROW_STATUS.FINALIZATION_SUGGESTED;
  }

  return (
    <button type="button" className="order-row" onClick={onSelect}>
      <div className="order-product">
        {image ? (
          <img src={image} alt={product?.title || "Product"} />
        ) : (
          <div className="order-image-placeholder">No image</div>
        )}

        <div>
          <strong>{product?.title || "Product"}</strong>

          <span>{merchant?.store_name || shortenAddress(order.seller)}</span>

          <small>Qty {order.quantity}</small>
        </div>
      </div>

      <div className="order-value">
        <small>Order value</small>

        <strong>{mistToSui(order.total_price)} SUI</strong>
      </div>

      <div className="order-status">
        {needsAction && (
          <span className="order-action-badge">Action needed</span>
        )}

        <span className={`order-status-badge status-${status}`}>
          {escrow ? getEscrowStatusLabel(status) : "Escrow unavailable"}
        </span>
      </div>

      <span className="order-arrow">›</span>
    </button>
  );
}

function purchaseOfferStatus(offer) {
  if (offer.accepted) return "Accepted";
  if (offer.rejected) return "Rejected";
  if (offer.withdrawn) return "Withdrawn";
  if (!offer.active) return "Inactive";
  if (Number(offer.expires_at ?? 0) <= Date.now()) return "Expired";
  return "Pending";
}

function PurchaseOfferList({
  offers,
  role,
  onAccept,
  onAction,
  processingOfferId,
}) {
  if (!offers.length) {
    return (
      <div className="orders-empty">
        No {role === "buyer" ? "submitted" : "received"} offers yet.
      </div>
    );
  }

  return (
    <div className="orders-list">
      {offers.map((offer) => {
        const pending =
          offer.active &&
          !offer.accepted &&
          !offer.rejected &&
          !offer.withdrawn &&
          Number(offer.expires_at) > Date.now();

        const busy = Boolean(processingOfferId);
        const processing = processingOfferId === offer.objectId;

        return (
          <div
            className="order-row"
            key={offer.objectId}
            style={{ cursor: "default" }}
          >
            <div className="order-product">
              <div>
                <strong>Purchase offer</strong>
                <span>
                  {role === "buyer" ? "Seller" : "Buyer"}:{" "}
                  {shortenAddress(
                    role === "buyer" ? offer.seller : offer.buyer
                  )}
                </span>
                <small>
                  Qty {offer.quantity} · {mistToSui(offer.unit_price)} SUI each
                </small>
                <small>Product: {shortenAddress(offer.product)}</small>
              </div>
            </div>

            <div className="order-value">
              <small>Offer total</small>
              <strong>{mistToSui(offer.total_price)} SUI</strong>
              <small>
                Expires: {new Date(Number(offer.expires_at)).toLocaleString()}
              </small>
            </div>

            <div className="order-status">
              <span className="order-status-badge">
                {purchaseOfferStatus(offer)}
              </span>

              {role === "seller" && pending && (
                <>
                  <button
                    type="button"
                    className="orders-refresh-button"
                    disabled={busy}
                    onClick={() => onAccept?.(offer)}
                  >
                    {processing ? "Processing..." : "Accept Offer"}
                  </button>

                  <button
                    type="button"
                    className="orders-refresh-button"
                    disabled={busy}
                    onClick={() => onAction?.(offer, "reject")}
                  >
                    {processing ? "Processing..." : "Reject Offer"}
                  </button>
                </>
              )}

              {role === "buyer" && pending && (
                <button
                  type="button"
                  className="orders-refresh-button"
                  disabled={busy}
                  onClick={() => onAction?.(offer, "withdraw")}
                >
                  {processing ? "Processing..." : "Withdraw + Refund"}
                </button>
              )}

              {role === "buyer" &&
                offer.rejected &&
                !offer.accepted &&
                !offer.refunded &&
                !offer.refundStatusUnknown && (
                  <button
                    type="button"
                    className="orders-refresh-button"
                    disabled={busy}
                    onClick={() => onAction?.(offer, "refund")}
                  >
                    {processing ? "Processing..." : "Claim Refund"}
                  </button>
                )}

              {role === "buyer" && offer.refunded && (
                <small style={{ color: "#16a34a", fontWeight: 600 }}>
                  Refund Completed
                </small>
              )}
            </div>
          </div>
        );
      })}
    </div>
  );
}
