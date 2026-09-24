import { useCallback, useEffect, useState } from "react";
import { Link, useParams } from "react-router-dom";

import { useCurrentAccount, useDAppKit } from "@mysten/dapp-kit-react";
import { Transaction } from "@mysten/sui/transactions";
import { MARKETPLACE_LATEST_PACKAGE_ID } from "../config";

import {
  getOrderRecordByEscrow,
  getProduct,
  getMerchantByAuthority,
} from "../lib/marketplaceData";

import {
  ESCROW_STATUS,
  getMarketplaceEscrow,
  getEscrowStatusLabel,
  sellerAcceptOrderTx,
  sellerSuggestCompletionTx,
  rejectFinalizationTx,
  acceptCompletionTx,
  withdrawBuyerOrderTx,
  isMutualCancellationProposal,
  isCompletedMutualCancellation,
  getMutualCancellationReason,
  requestMutualCancellationTx,
  acceptMutualCancellationTx,
  rejectMutualCancellationTx,
} from "../lib/escrow";

import "./OrderDetailsPage.css";

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

function shortAddress(address) {
  if (!address) return "—";

  if (address.length <= 18) {
    return address;
  }

  return `${address.slice(0, 10)}...${address.slice(-8)}`;
}

export default function OrderDetailsPage() {
  const { role, escrowAddress } = useParams();

  const account = useCurrentAccount();
  const dAppKit = useDAppKit();

  const [order, setOrder] = useState(null);
  const [escrow, setEscrow] = useState(null);
  const [product, setProduct] = useState(null);
  const [merchant, setMerchant] = useState(null);

  const [loading, setLoading] = useState(true);
  const [processing, setProcessing] = useState(false);

  const [error, setError] = useState("");
  const [message, setMessage] = useState("");

  const [donationPercent, setDonationPercent] = useState("0");

  const [cancellationReason, setCancellationReason] = useState("");

  const loadOrder = useCallback(async () => {
    if (!escrowAddress) return;

    try {
      setLoading(true);
      setError("");

      const escrowData = await getMarketplaceEscrow(escrowAddress);

      if (!escrowData) {
        throw new Error("Escrow was not found.");
      }

      const orderData = await getOrderRecordByEscrow(escrowAddress);


      if (!orderData) {
        throw new Error("Marketplace order record was not found.");
      }

      const productData = await getProduct(orderData.product);

      const merchantData = await getMerchantByAuthority(orderData.seller);

      setEscrow(escrowData);
      setOrder(orderData);
      setProduct(productData);
      setMerchant(merchantData);
    } catch (err) {
      console.error("Load order details error:", err);

      setError(err?.message || "Failed to load order.");
    } finally {
      setLoading(false);
    }
  }, [escrowAddress]);

  useEffect(() => {
    loadOrder();
  }, [loadOrder]);

  async function runTransaction(transaction, successMessage) {
    try {
      setProcessing(true);
      setMessage("");
      setError("");

      const result = await dAppKit.signAndExecuteTransaction({
        transaction,
      });

      if (result.FailedTransaction) {
        throw new Error(
          result.FailedTransaction.status?.error?.message ||
            "Transaction failed."
        );
      }

      const digest = result.Transaction?.digest;

      setMessage(
        digest ? `${successMessage} Transaction: ${digest}` : successMessage
      );

      /*
       * Give the indexer a short moment
       * before refreshing the objects.
       */
      await new Promise((resolve) => setTimeout(resolve, 800));

      await loadOrder();

      return true;
    } catch (err) {
      console.error("Order transaction error:", err);

      setError(err?.message || "Transaction failed.");

      return false;
    } finally {
      setProcessing(false);
    }
  }

  if (loading) {
    return (
      <main className="order-detail-page">
        <div className="order-detail-shell">
          <p>Loading order...</p>
        </div>
      </main>
    );
  }

  if (error && !escrow) {
    return (
      <main className="order-detail-page">
        <div className="order-detail-shell">
          <Link to="/orders" className="order-detail-back">
            ← Back to Orders
          </Link>

          <div className="order-detail-error">{error}</div>
        </div>
      </main>
    );
  }

  if (!escrow || !order) {
    return null;
  }

  const walletAddress = account?.address?.toLowerCase() ?? "";

  const buyer = escrow.partyA?.toLowerCase() ?? "";

  const seller = escrow.partyB?.toLowerCase() ?? "";

  const isBuyer = walletAddress && walletAddress === buyer;

  const isSeller = walletAddress && walletAddress === seller;

  const status = Number(escrow.status);

  const buyerDeposit = BigInt(escrow.depositedA ?? 0);

  const sellerDeposit = BigInt(escrow.depositedB ?? 0);

  const requiredBuyerDeposit = BigInt(escrow.requiredDepositA ?? 0);

  const requiredSellerDeposit = BigInt(escrow.requiredDepositB ?? 0);

  const productTotal = BigInt(escrow.referenceAmount ?? 0);

  const buyerSecurityDeposit = requiredBuyerDeposit - productTotal;

  const canSellerAccept =
    isSeller &&
    status === ESCROW_STATUS.CREATED &&
    buyerDeposit > 0n &&
    sellerDeposit === 0n;

  const canBuyerWithdraw =
    isBuyer &&
    status === ESCROW_STATUS.CREATED &&
    buyerDeposit > 0n &&
    sellerDeposit === 0n;

  const canSellerComplete =
    isSeller && status === ESCROW_STATUS.DEPOSITS_COMPLETE;

  const isFinalizationPending = status === ESCROW_STATUS.FINALIZATION_SUGGESTED;

  const proposer = escrow.finalizationProposer?.toLowerCase() ?? "";

  const mutualCancellationPending = isMutualCancellationProposal(escrow);

  const mutualCancellationCompleted = isCompletedMutualCancellation(escrow);

  const cancellationReasonText = getMutualCancellationReason(escrow);

  const canRequestMutualCancellation =
    (isBuyer || isSeller) && status === ESCROW_STATUS.DEPOSITS_COMPLETE;

  const canRespondToMutualCancellation =
    (isBuyer || isSeller) &&
    mutualCancellationPending &&
    proposer !== walletAddress;

  const currentUserRequestedCancellation =
    mutualCancellationPending && proposer === walletAddress;

  const canBuyerAcceptCompletion =
    isBuyer &&
    isFinalizationPending &&
    !mutualCancellationPending &&
    proposer === seller;

  const canBuyerRejectCompletion =
    isBuyer &&
    isFinalizationPending &&
    !mutualCancellationPending &&
    proposer === seller;

  async function acceptOrder() {
    const confirmed = window.confirm(
      `Accept this order?\n\n` +
        `Seller security deposit: ` +
        `${formatSui(requiredSellerDeposit)} SUI`
    );

    if (!confirmed) return;

    const tx = sellerAcceptOrderTx({
      escrowId: escrow.objectId,
      securityDeposit: escrow.requiredDepositB,
    });

    await runTransaction(tx, "Order accepted and seller deposit submitted.");
  }

  async function withdrawOrder() {
    const confirmed = window.confirm(
      "Withdraw this order?\n\n" +
        "Your deposited funds will be returned and the reserved product stock will be restored."
    );

    if (!confirmed) return;

    const tx = withdrawBuyerOrderTx({
      escrowId: escrow.objectId,
      productId: order.product,
      orderId: order.objectId,
    });

    await runTransaction(tx, "Order cancelled and buyer deposit returned.");
  }

  async function proposeCompletion() {
    const percent = Number(donationPercent);

    const confirmed = window.confirm(
      `Mark this order ready for buyer confirmation?\n\n` +
        `Website donation: ${percent}%`
    );

    if (!confirmed) return;

    const tx = sellerSuggestCompletionTx({
      escrowId: escrow.objectId,
      escrow,
      walletAddress: account?.address,
      donationPercent: percent,
    });

    await runTransaction(tx, "Order marked ready for buyer confirmation.");
  }

  async function acceptCompletion() {
    const buyerRefund = formatSui(escrow.proposedPayoutA);

    const sellerPayout = formatSui(escrow.proposedPayoutB);

    const donation = formatSui(escrow.proposedDonation);

    const confirmed = window.confirm(
      `Confirm that you received the product?\n\n` +
        `${buyerRefund} SUI will be returned to you.\n` +
        `${sellerPayout} SUI will be released to the seller.\n` +
        `Donation: ${donation} SUI\n\n` +
        `This action completes the order.`
    );

    if (!confirmed) return;

    if (!merchant?.objectId) {
      setError("Seller merchant profile was not found.");
      return;
    }

    const tx = acceptCompletionTx({
      escrowId: escrow.objectId,
      merchantId: merchant.objectId,
      productId: order.product,
      orderId: order.objectId,
      escrow,
      walletAddress: account?.address,
    });

    await runTransaction(
      tx,
      "Your deposit was returned and the seller was paid."
    );
  }

  async function rejectCompletion() {
    const confirmed = window.confirm(
      "Reject the seller's completion proposal?"
    );

    if (!confirmed) return;

    const tx = rejectFinalizationTx({
      escrowId: escrow.objectId,
    });

    await runTransaction(tx, "Ready status rejected.");
  }

  async function testDoubleStockRestore() {
    const tx = new Transaction();

    tx.moveCall({
      target:
        `${MARKETPLACE_LATEST_PACKAGE_ID}` +
        `::marketplace::restore_mutually_cancelled_order_stock`,
      arguments: [
        tx.object(order.product),
        tx.object(order.objectId),
        tx.object(escrow.objectId),
      ],
    });

    const success = await runTransaction(
      tx,
      "SECURITY FAILURE: stock was restored twice!"
    );

    if (success) {
      console.error(
        "SECURITY TEST FAILED: double stock restoration succeeded."
      );
    } else {
      console.log(
        "SECURITY TEST PASSED: double stock restoration was rejected."
      );
    }
  }

  async function testWrongProduct() {
    const wrongProductId =
      "0x5700e7904c1a4be0ffc0faaba3e27ef1830df67421e3349585f9f5ee26c269b4";

    const tx = new Transaction();

    tx.moveCall({
      target:
        `${MARKETPLACE_LATEST_PACKAGE_ID}` +
        `::marketplace::restore_mutually_cancelled_order_stock`,
      arguments: [
        tx.object(wrongProductId),
        tx.object(order.objectId),
        tx.object(escrow.objectId),
      ],
    });

    const success = await runTransaction(
      tx,
      "SECURITY FAILURE: wrong product was accepted!"
    );

    if (success) {
      console.error("SECURITY TEST FAILED: wrong product was accepted.");
    } else {
      console.log("SECURITY TEST PASSED: wrong product was rejected.");
    }
  }

  async function requestCancellation() {
    const reason = cancellationReason.trim();

    if (!reason) {
      setError("Enter a cancellation reason.");
      return;
    }

    const confirmed = window.confirm(
      `Request mutual cancellation?\n\n` +
        `Reason: ${reason}\n\n` +
        `Buyer refund: ${formatSui(escrow.depositedA)} SUI\n` +
        `Seller refund: ${formatSui(escrow.depositedB)} SUI\n\n` +
        `The other party must approve this request.`
    );

    if (!confirmed) return;

    const tx = requestMutualCancellationTx({
      escrowId: escrow.objectId,
      escrow,
      walletAddress: account?.address,
      reason,
    });

    const success = await runTransaction(tx, "Mutual cancellation requested.");

    if (success) {
      setCancellationReason("");
    }
  }

  async function acceptCancellation() {
    const confirmed = window.confirm(
      `Approve mutual cancellation?\n\n` +
        `Buyer refund: ${formatSui(escrow.proposedPayoutA)} SUI\n` +
        `Seller refund: ${formatSui(escrow.proposedPayoutB)} SUI\n\n` +
        `The order will be cancelled and the reserved stock will be restored.`
    );

    if (!confirmed) return;

    const tx = acceptMutualCancellationTx({
      escrowId: escrow.objectId,
      productId: order.product,
      orderId: order.objectId,
      escrow,
      walletAddress: account?.address,
    });

    await runTransaction(
      tx,
      "Mutual cancellation approved. Funds returned and stock restored."
    );
  }

  async function rejectCancellation() {
    const confirmed = window.confirm(
      "Reject this mutual cancellation request?\n\n" +
        "No funds will move and the order will remain active."
    );

    if (!confirmed) return;

    const tx = rejectMutualCancellationTx({
      escrowId: escrow.objectId,
      escrow,
      walletAddress: account?.address,
    });

    await runTransaction(tx, "Mutual cancellation request rejected.");
  }

  return (
    <main className="order-detail-page">
      <div className="order-detail-shell">
        <Link to="/orders" className="order-detail-back">
          ← Back to Orders
        </Link>

        <div className="order-detail-header">
          <div>
            <span className="order-detail-label">
              {role === "seller" ? "Seller Order" : "Purchase"}
            </span>

            <h1>{product?.title || "Order Details"}</h1>

            <p>{merchant?.store_name || "Marketplace order"}</p>
          </div>

          <span className={`order-detail-status status-${status}`}>
            {mutualCancellationCompleted
              ? "Cancelled"
              : getEscrowStatusLabel(status)}
          </span>
        </div>

        {error && <div className="order-detail-error">{error}</div>}

        {message && <div className="order-detail-success">{message}</div>}

        <div className="order-detail-grid">
          <section className="order-detail-card">
            <h2>Order Summary</h2>

            <div className="detail-row">
              <span>Quantity</span>
              <strong>{order.quantity}</strong>
            </div>

            <div className="detail-row">
              <span>Product total</span>
              <strong>{formatSui(order.total_price)} SUI</strong>
            </div>

            <div className="detail-row">
              <span>Buyer security</span>

              <strong>{formatSui(buyerSecurityDeposit)} SUI</strong>
            </div>

            <div className="detail-row">
              <span>Seller security</span>

              <strong>{formatSui(requiredSellerDeposit)} SUI</strong>
            </div>
          </section>

          <section className="order-detail-card">
            <h2>Deposits</h2>

            <div className="detail-row">
              <span>Buyer</span>

              <strong>
                {formatSui(buyerDeposit)} / {formatSui(requiredBuyerDeposit)}{" "}
                SUI
              </strong>
            </div>

            <div className="detail-row">
              <span>Seller</span>

              <strong>
                {formatSui(sellerDeposit)} / {formatSui(requiredSellerDeposit)}{" "}
                SUI
              </strong>
            </div>
          </section>

          <section className="order-detail-card order-addresses">
            <h2>Order Parties</h2>

            <div className="detail-row">
              <span>Buyer</span>

              <strong title={escrow.partyA}>
                {shortAddress(escrow.partyA)}
              </strong>
            </div>

            <div className="detail-row">
              <span>Seller</span>

              <strong title={escrow.partyB}>
                {shortAddress(escrow.partyB)}
              </strong>
            </div>

            <div className="detail-row">
              <span>Escrow</span>

              <strong title={escrow.objectId}>
                {shortAddress(escrow.objectId)}
              </strong>
            </div>
          </section>
        </div>

        <section className="order-action-card">
          <h2>Order Actions</h2>

          {!account && <p>Connect your wallet to manage this order.</p>}

          {account && !isBuyer && !isSeller && (
            <p>This wallet is not a party to this order.</p>
          )}

          {canSellerAccept && (
            <>
              <p>
                The buyer has deposited the payment. Deposit your refundable
                security bond to accept the order.
              </p>

              <button
                type="button"
                className="order-primary-button"
                disabled={processing}
                onClick={acceptOrder}
              >
                {processing
                  ? "Processing..."
                  : `Accept Order — Deposit ${formatSui(
                      requiredSellerDeposit
                    )} SUI`}
              </button>
            </>
          )}

          {canBuyerWithdraw && (
            <>
              <p>Waiting for the seller to accept this order.</p>

              <button
                type="button"
                className="order-danger-button"
                disabled={processing}
                onClick={withdrawOrder}
              >
                {processing ? "Processing..." : "Withdraw Order"}
              </button>
            </>
          )}

          {canSellerComplete && (
            <>
              <p>
                When the product has been delivered or fulfilled, mark the order
                ready for buyer confirmation.
              </p>

              <div className="donation-field">
                <div className="donation-header">
                  <div>
                    <strong>Website Donation</strong>

                    <span className="donation-optional">Optional</span>
                  </div>

                  <strong className="donation-value">{donationPercent}%</strong>
                </div>

                <p className="donation-help">
                  Support the marketplace by donating a percentage of the
                  product sale.
                </p>

                <input
                  className="donation-slider"
                  type="range"
                  min="0"
                  max="100"
                  step="0.5"
                  value={donationPercent}
                  onChange={(event) => setDonationPercent(event.target.value)}
                  disabled={processing}
                />

                <div className="donation-range">
                  <span>0%</span>
                  <span>100%</span>
                </div>
              </div>

              <button
                type="button"
                className="order-primary-button"
                disabled={processing}
                onClick={proposeCompletion}
              >
                {processing ? "Processing..." : "Mark Order Ready"}
              </button>
            </>
          )}

          {canRequestMutualCancellation && (
            <div className="mutual-cancellation-panel">
              <p>
                Need to cancel this accepted order? Either the buyer or seller
                may request mutual cancellation. The other party must approve
                before any funds are returned.
              </p>

              <label htmlFor="cancellation-reason">Cancellation reason</label>

              <textarea
                id="cancellation-reason"
                value={cancellationReason}
                onChange={(event) => setCancellationReason(event.target.value)}
                placeholder="Enter reason for cancellation"
                rows={3}
                disabled={processing}
              />

              <button
                type="button"
                className="order-danger-button"
                disabled={processing || !cancellationReason.trim()}
                onClick={requestCancellation}
              >
                {processing ? "Processing..." : "Request Mutual Cancellation"}
              </button>
            </div>
          )}

          {mutualCancellationPending && (
            <>
              <p>
                <strong>Mutual cancellation requested.</strong>
              </p>

              <p>
                Requested by:{" "}
                <strong>{proposer === buyer ? "Buyer" : "Seller"}</strong>
              </p>

              {cancellationReasonText && (
                <p>
                  Reason: <strong>{cancellationReasonText}</strong>
                </p>
              )}

              <div className="completion-preview">
                <div>
                  <span>Refund to buyer</span>

                  <strong>{formatSui(escrow.proposedPayoutA)} SUI</strong>
                </div>

                <div>
                  <span>Refund to seller</span>

                  <strong>{formatSui(escrow.proposedPayoutB)} SUI</strong>
                </div>
              </div>

              {currentUserRequestedCancellation && (
                <p>
                  Waiting for the other party to respond to your cancellation
                  request.
                </p>
              )}

              {canRespondToMutualCancellation && (
                <div className="order-action-buttons">
                  <button
                    type="button"
                    className="order-primary-button"
                    disabled={processing}
                    onClick={acceptCancellation}
                  >
                    {processing ? "Processing..." : "Approve Cancellation"}
                  </button>

                  <button
                    type="button"
                    className="order-secondary-button"
                    disabled={processing}
                    onClick={rejectCancellation}
                  >
                    Reject Cancellation
                  </button>
                </div>
              )}
            </>
          )}

          {canBuyerAcceptCompletion && (
            <>
              <p>
                The seller marked this order ready. Confirm only after you have
                received the product.
              </p>

              <div className="completion-preview">
                <div>
                  <span>Returned to you</span>

                  <strong>{formatSui(escrow.proposedPayoutA)} SUI</strong>
                </div>

                <div>
                  <span>Seller receives</span>

                  <strong>{formatSui(escrow.proposedPayoutB)} SUI</strong>
                </div>

                <div>
                  <span>Donation</span>

                  <strong>{formatSui(escrow.proposedDonation)} SUI</strong>
                </div>
              </div>

              <div className="order-action-buttons">
                <button
                  type="button"
                  className="order-primary-button"
                  disabled={processing}
                  onClick={acceptCompletion}
                >
                  {processing ? "Processing..." : "Confirm Product Received"}
                </button>

                <button
                  type="button"
                  className="order-secondary-button"
                  disabled={processing}
                  onClick={rejectCompletion}
                >
                  Reject
                </button>
              </div>
            </>
          )}

          {isSeller &&
            isFinalizationPending &&
            !mutualCancellationPending &&
            proposer === seller && (
              <p>Waiting for the buyer to confirm receipt of the product.</p>
            )}

          {status === ESCROW_STATUS.COMPLETED &&
            !mutualCancellationCompleted && (
              <p className="order-completed-message">
                ✓ This order has been completed.
              </p>
            )}

          {mutualCancellationCompleted && (
            <>
              <p className="order-completed-message">
                ✓ This order was cancelled by mutual agreement. Both parties
                were refunded.
              </p>

              <button
                type="button"
                className="order-danger-button"
                disabled={processing}
                onClick={testDoubleStockRestore}
              >
                {processing
                  ? "Testing..."
                  : "SECURITY TEST — Replay Stock Restore"}
              </button>

              <button
                type="button"
                className="order-danger-button"
                disabled={processing}
                onClick={testWrongProduct}
              >
                {processing ? "Testing..." : "SECURITY TEST — Wrong Product"}
              </button>
            </>
          )}

          {status === ESCROW_STATUS.CANCELLED && (
            <p>This order was cancelled.</p>
          )}
        </section>
      </div>
    </main>
  );
}
