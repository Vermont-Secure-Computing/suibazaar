import { SuiGrpcClient } from "@mysten/sui/grpc";

import { Transaction, coinWithBalance } from "@mysten/sui/transactions";

import {
  ESCROW_PACKAGE_ID,
  ESCROW_LATEST_PACKAGE_ID,
  MARKETPLACE_LATEST_PACKAGE_ID,
  CLOCK_ID,
  MODULE,
} from "../config";

const client = new SuiGrpcClient({
  network: "devnet",
  baseUrl: "https://fullnode.devnet.sui.io:443",
});

export const ESCROW_STATUS = {
  CREATED: 0,
  DEPOSITS_COMPLETE: 1,
  FINALIZATION_SUGGESTED: 2,
  COMPLETED: 3,
  CANCELLED: 4,
};

export const MUTUAL_CANCELLATION_PREFIX =
  "MUTUAL_CANCELLATION|";

export function isMutualCancellationProposal(escrow) {
  if (!escrow) {
    return false;
  }

  const exactRefund =
    BigInt(escrow.proposedPayoutA ?? 0) ===
      BigInt(escrow.depositedA ?? 0) &&
    BigInt(escrow.proposedPayoutB ?? 0) ===
      BigInt(escrow.depositedB ?? 0) &&
    BigInt(escrow.proposedDonation ?? 0) === 0n;

  return (
    Number(escrow.status) ===
      ESCROW_STATUS.FINALIZATION_SUGGESTED &&
    String(escrow.finalizationNote ?? "").startsWith(
      MUTUAL_CANCELLATION_PREFIX
    ) &&
    exactRefund
  );
}

export function isCompletedMutualCancellation(escrow) {
  if (!escrow) {
    return false;
  }

  return (
    Number(escrow.status) === ESCROW_STATUS.COMPLETED &&
    String(escrow.finalizationNote ?? "").startsWith(
      MUTUAL_CANCELLATION_PREFIX
    ) &&
    BigInt(escrow.proposedPayoutA ?? 0) ===
      BigInt(escrow.depositedA ?? 0) &&
    BigInt(escrow.proposedPayoutB ?? 0) ===
      BigInt(escrow.depositedB ?? 0) &&
    BigInt(escrow.proposedDonation ?? 0) === 0n
  );
}

export function getMutualCancellationReason(escrow) {
  const note = String(escrow?.finalizationNote ?? "");

  if (!note.startsWith(MUTUAL_CANCELLATION_PREFIX)) {
    return "";
  }

  const marker = "|reason=";
  const index = note.indexOf(marker);

  if (index < 0) {
    return "";
  }

  return note.slice(index + marker.length).trim();
}

export function getEscrowStatusLabel(status) {
  switch (Number(status)) {
    case ESCROW_STATUS.CREATED:
      return "Waiting for deposits";

    case ESCROW_STATUS.DEPOSITS_COMPLETE:
      return "Order accepted";

    case ESCROW_STATUS.FINALIZATION_SUGGESTED:
      return "Finalization pending";

    case ESCROW_STATUS.COMPLETED:
      return "Completed";

    case ESCROW_STATUS.CANCELLED:
      return "Cancelled";

    default:
      return "Unknown";
  }
}

function decodeBytes(value) {
  if (!value) return "";

  /*
   * Sui gRPC may return vector<u8> fields as
   * Base64 strings instead of byte arrays.
   */
  if (typeof value === "string") {
    try {
      const binary = atob(value);

      const bytes = Uint8Array.from(
        binary,
        (char) => char.charCodeAt(0)
      );

      const decoded =
        new TextDecoder().decode(bytes);

      /*
       * Only use the decoded value when it
       * looks like valid text.
       */
      if (decoded) {
        return decoded;
      }
    } catch {
      /*
       * Not Base64. Fall back to the
       * original string.
       */
    }

    return value;
  }

  if (!Array.isArray(value)) {
    return "";
  }

  try {
    return new TextDecoder().decode(
      Uint8Array.from(value)
    );
  } catch {
    return "";
  }
}

function unwrapOption(value) {
  if (value == null) {
    return null;
  }

  /*
   * Depending on the JSON representation,
   * Move Option may already be returned as
   * the contained value.
   */
  if (typeof value === "string") {
    return value;
  }

  if (Array.isArray(value)) {
    return value.length > 0 ? value[0] : null;
  }

  if (typeof value === "object") {
    if ("Some" in value) {
      return value.Some;
    }

    if ("some" in value) {
      return value.some;
    }

    if ("vec" in value) {
      return value.vec?.[0] ?? null;
    }
  }

  return value;
}

export async function getEscrow(escrowId) {
  if (!escrowId) {
    throw new Error("Escrow object ID is required.");
  }

  const result = await client.getObject({
    objectId: escrowId,
    include: {
      json: true,
    },
  });

  if (!result?.object) {
    return null;
  }

  const object = result.object;
  const data = object.json ?? {};

  return {
    objectId: object.objectId,

    creator: data.creator ?? null,

    partyA: unwrapOption(data.party_a),

    partyB: unwrapOption(data.party_b),

    escrowType: Number(data.escrow_type ?? 0),

    referenceAmount: String(data.reference_amount ?? 0),

    requiredDepositA: String(data.required_deposit_a ?? 0),

    requiredDepositB: String(data.required_deposit_b ?? 0),

    depositedA: String(data.deposited_a ?? 0),

    depositedB: String(data.deposited_b ?? 0),

    proposedPayoutA: String(data.proposed_payout_a ?? 0),

    proposedPayoutB: String(data.proposed_payout_b ?? 0),

    proposedDonation: String(data.proposed_donation ?? 0),

    finalizationProposer: unwrapOption(data.finalization_proposer),

    finalizationNote: decodeBytes(data.finalization_note),

    status: Number(data.status ?? 0),

    createdAt: Number(data.created_at ?? 0),

    depositAt: Number(data.deposit_at ?? 0),

    finalizedAt: Number(data.finalized_at ?? 0),

    note: decodeBytes(data.note),

    raw: data,
  };
}

export function parseMarketplaceOrderNote(escrow) {
  if (!escrow?.note) {
    return null;
  }

  try {
    const parsed = JSON.parse(escrow.note);

    if (parsed?.marketplace !== "solbazaar") {
      return null;
    }

    return parsed;
  } catch {
    return null;
  }
}

export async function getMarketplaceEscrow(escrowId) {
  const escrow = await getEscrow(escrowId);

  if (!escrow) {
    return null;
  }

  return {
    ...escrow,
    order: parseMarketplaceOrderNote(escrow),
  };
}

const ESCROW_MODULE = "escrow";

function requireIds() {
  if (!ESCROW_LATEST_PACKAGE_ID) {
    throw new Error("VITE_ESCROW_LATEST_PACKAGE_ID is not set.");
  }

  if (!MARKETPLACE_LATEST_PACKAGE_ID) {
    throw new Error("VITE_MARKETPLACE_LATEST_PACKAGE_ID is not set.");
  }
}

/*
 * Seller accepts the order by depositing the exact
 * required seller security deposit.
 */
export function sellerAcceptOrderTx({ escrowId, securityDeposit }) {
  requireIds();

  const amount = BigInt(securityDeposit);

  if (amount <= 0n) {
    throw new Error("Invalid seller security deposit.");
  }

  const tx = new Transaction();

  const depositCoin = coinWithBalance({
    balance: amount,
  });

  tx.moveCall({
    target: `${ESCROW_LATEST_PACKAGE_ID}` + `::${ESCROW_MODULE}::deposit`,

    arguments: [tx.object(escrowId), depositCoin, tx.object(CLOCK_ID)],
  });

  return tx;
}

/*
 * Normal successful marketplace completion.
 *
 * Buyer receives their security deposit back.
 * Seller receives:
 *   product total + seller security deposit.
 *
 * Donation = 0.
 */
export function sellerSuggestCompletionTx({
  escrowId,
  escrow,
  walletAddress,
  donationPercent = 0,
}) {
  requireIds();

  if (!walletAddress) {
    throw new Error("Connect wallet first.");
  }

  if (walletAddress.toLowerCase() !== escrow.partyB?.toLowerCase()) {
    throw new Error("Only the seller can propose order completion.");
  }

  if (Number(escrow.status) !== ESCROW_STATUS.DEPOSITS_COMPLETE) {
    throw new Error("Both deposits must be complete first.");
  }

  const percent = Number(donationPercent);

  if (!Number.isFinite(percent) || percent < 0 || percent > 100) {
    throw new Error("Donation must be between 0% and 100%.");
  }

  const productPrice = BigInt(escrow.referenceAmount);

  const buyerRequiredDeposit = BigInt(escrow.requiredDepositA);

  const sellerRequiredDeposit = BigInt(escrow.requiredDepositB);

  /*
   * Same as original SolBazaar:
   * return buyer's refundable security deposit.
   */
  const buyerRefund = buyerRequiredDeposit - productPrice;

  /*
   * Support decimals such as 2.5%.
   */
  const donationBasisPoints = BigInt(Math.round(percent * 100));

  const donation = (productPrice * donationBasisPoints) / 10_000n;

  /*
   * Same as SolBazaar:
   *
   * seller =
   * product price
   * + seller refundable deposit
   * - donation
   */
  const sellerPayout = productPrice + sellerRequiredDeposit - donation;

  if (sellerPayout < 0n) {
    throw new Error("Donation exceeds seller proceeds.");
  }

  const totalLocked = BigInt(escrow.depositedA) + BigInt(escrow.depositedB);

  const allocatedTotal = buyerRefund + sellerPayout + donation;

  if (allocatedTotal !== totalLocked) {
    throw new Error("Final payouts do not match the escrow balance.");
  }

  const note = `Seller marked order ready. Website donation: ${percent}%`;

  const tx = new Transaction();

  tx.moveCall({
    target:
      `${ESCROW_LATEST_PACKAGE_ID}` +
      `::${ESCROW_MODULE}::suggest_finalization`,

    arguments: [
      tx.object(escrowId),
      tx.pure.u64(buyerRefund),
      tx.pure.u64(sellerPayout),
      tx.pure.u64(donation),
      tx.pure.vector("u8", Array.from(new TextEncoder().encode(note))),
    ],
  });

  return tx;
}

/*
 * Either buyer or seller may request mutual cancellation
 * after both deposits are complete.
 *
 * Each party receives exactly its own deposited funds.
 */
export function requestMutualCancellationTx({
  escrowId,
  escrow,
  walletAddress,
  reason,
}) {
  requireIds();

  if (!walletAddress) {
    throw new Error("Connect wallet first.");
  }

  const signer = walletAddress.toLowerCase();
  const buyer = escrow.partyA?.toLowerCase();
  const seller = escrow.partyB?.toLowerCase();

  if (signer !== buyer && signer !== seller) {
    throw new Error(
      "Only the buyer or seller can request cancellation."
    );
  }

  if (
    Number(escrow.status) !==
    ESCROW_STATUS.DEPOSITS_COMPLETE
  ) {
    throw new Error(
      "Mutual cancellation is available only after both deposits are complete."
    );
  }

  const cleanReason = String(reason ?? "")
    .trim()
    .replace(/\s+/g, " ");

  if (!cleanReason) {
    throw new Error("Enter a cancellation reason.");
  }

  const requesterRole =
    signer === buyer ? "buyer" : "seller";

  const note =
    `${MUTUAL_CANCELLATION_PREFIX}` +
    `requester=${requesterRole}` +
    `|reason=${cleanReason}`;

  const noteBytes =
    Array.from(new TextEncoder().encode(note));

  if (noteBytes.length > 200) {
    throw new Error("Cancellation reason is too long.");
  }

  const buyerPayout =
    BigInt(escrow.depositedA);

  const sellerPayout =
    BigInt(escrow.depositedB);

  const donation = 0n;

  const tx = new Transaction();

  tx.moveCall({
    target:
      `${ESCROW_LATEST_PACKAGE_ID}` +
      `::${ESCROW_MODULE}::suggest_finalization`,

    arguments: [
      tx.object(escrowId),
      tx.pure.u64(buyerPayout),
      tx.pure.u64(sellerPayout),
      tx.pure.u64(donation),
      tx.pure.vector("u8", noteBytes),
    ],
  });

  return tx;
}


/*
 * The other party accepts mutual cancellation.
 *
 * Escrow refund and marketplace stock restoration
 * happen atomically.
 */
export function acceptMutualCancellationTx({
  escrowId,
  productId,
  orderId,
  escrow,
  walletAddress,
}) {
  requireIds();

  if (!walletAddress) {
    throw new Error("Connect wallet first.");
  }

  if (!isMutualCancellationProposal(escrow)) {
    throw new Error(
      "No valid mutual cancellation request is pending."
    );
  }

  const signer =
    walletAddress.toLowerCase();

  const buyer =
    escrow.partyA?.toLowerCase();

  const seller =
    escrow.partyB?.toLowerCase();

  const proposer =
    escrow.finalizationProposer?.toLowerCase();

  if (signer !== buyer && signer !== seller) {
    throw new Error(
      "Only the buyer or seller can approve cancellation."
    );
  }

  if (signer === proposer) {
    throw new Error(
      "You cannot approve your own cancellation request."
    );
  }

  const tx = new Transaction();

  tx.moveCall({
    target:
      `${ESCROW_LATEST_PACKAGE_ID}` +
      `::${ESCROW_MODULE}::accept_finalization`,

    arguments: [
      tx.object(escrowId),
      tx.object(CLOCK_ID),
    ],
  });

  tx.moveCall({
    target:
      `${MARKETPLACE_LATEST_PACKAGE_ID}` +
      `::${MODULE}::restore_mutually_cancelled_order_stock`,

    arguments: [
      tx.object(productId),
      tx.object(orderId),
      tx.object(escrowId),
    ],
  });

  return tx;
}


/*
 * The other party rejects mutual cancellation.
 *
 * No funds move. Escrow returns to
 * DEPOSITS_COMPLETE.
 */
export function rejectMutualCancellationTx({
  escrowId,
  escrow,
  walletAddress,
}) {
  requireIds();

  if (!walletAddress) {
    throw new Error("Connect wallet first.");
  }

  if (!isMutualCancellationProposal(escrow)) {
    throw new Error(
      "No valid mutual cancellation request is pending."
    );
  }

  const signer =
    walletAddress.toLowerCase();

  const buyer =
    escrow.partyA?.toLowerCase();

  const seller =
    escrow.partyB?.toLowerCase();

  const proposer =
    escrow.finalizationProposer?.toLowerCase();

  if (signer !== buyer && signer !== seller) {
    throw new Error(
      "Only the buyer or seller can reject cancellation."
    );
  }

  if (signer === proposer) {
    throw new Error(
      "You cannot reject your own cancellation request."
    );
  }

  const tx = new Transaction();

  tx.moveCall({
    target:
      `${ESCROW_LATEST_PACKAGE_ID}` +
      `::${ESCROW_MODULE}::reject_finalization`,

    arguments: [
      tx.object(escrowId),
    ],
  });

  return tx;
}

/*
 * The other party rejects a pending finalization.
 * Escrow returns to DEPOSITS_COMPLETE.
 */
export function rejectFinalizationTx({ escrowId }) {
  requireIds();

  const tx = new Transaction();

  tx.moveCall({
    target:
      `${ESCROW_LATEST_PACKAGE_ID}` + `::${ESCROW_MODULE}::reject_finalization`,

    arguments: [tx.object(escrowId)],
  });

  return tx;
}

/*
 * Accept finalization AND record the completed
 * marketplace sale atomically.
 *
 * If record_completed_sale fails, the whole
 * transaction fails, including accept_finalization.
 */
export function acceptCompletionTx({
  escrowId,
  merchantId,
  productId,
  orderId,
  escrow,
  walletAddress,
}) {
  requireIds();

  if (!walletAddress) {
    throw new Error("Connect wallet first.");
  }

  if (walletAddress.toLowerCase() !== escrow.partyA?.toLowerCase()) {
    throw new Error("Only the buyer can complete this order.");
  }

  if (Number(escrow.status) !== ESCROW_STATUS.FINALIZATION_SUGGESTED) {
    throw new Error("No finalization proposal is pending.");
  }

  if (
    escrow.finalizationProposer?.toLowerCase() === walletAddress.toLowerCase()
  ) {
    throw new Error("You cannot accept your own finalization proposal.");
  }

  const tx = new Transaction();

  tx.moveCall({
    target:
      `${ESCROW_LATEST_PACKAGE_ID}` + `::${ESCROW_MODULE}::accept_finalization`,

    arguments: [tx.object(escrowId), tx.object(CLOCK_ID)],
  });

  tx.moveCall({
    target:
      `${MARKETPLACE_LATEST_PACKAGE_ID}` + `::${MODULE}::record_completed_sale`,

    arguments: [
      tx.object(merchantId),
      tx.object(productId),
      tx.object(orderId),
      tx.object(escrowId),
    ],
  });

  return tx;
}

/*
 * Buyer cancels before both deposits are complete.
 *
 * Buyer refund + stock restoration happen in the
 * same Sui transaction.
 */
export function withdrawBuyerOrderTx({ escrowId, productId, orderId }) {
  requireIds();

  const tx = new Transaction();

  tx.moveCall({
    target:
      `${ESCROW_LATEST_PACKAGE_ID}` +
      `::${ESCROW_MODULE}::withdraw_before_complete`,

    arguments: [tx.object(escrowId)],
  });

  tx.moveCall({
    target:
      `${MARKETPLACE_LATEST_PACKAGE_ID}` +
      `::${MODULE}::restore_cancelled_order_stock`,

    arguments: [tx.object(productId), tx.object(orderId), tx.object(escrowId)],
  });

  return tx;
}
