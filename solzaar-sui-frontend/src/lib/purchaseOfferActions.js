
import { Transaction } from "@mysten/sui/transactions";
import {
  MARKETPLACE_LATEST_PACKAGE_ID,
  ESCROW_LATEST_PACKAGE_ID,
  MODULE,
} from "../config";

function required(value, label) {
  if (!value) throw new Error(`${label} is required.`);
}

function addEscrowRefund(tx, escrowId) {
  required(ESCROW_LATEST_PACKAGE_ID, "Escrow package ID");
  required(escrowId, "Escrow ID");

  tx.moveCall({
    target:
      `${ESCROW_LATEST_PACKAGE_ID}` +
      "::escrow::withdraw_before_complete",
    arguments: [tx.object(escrowId)],
  });
}

export function rejectPurchaseOfferTx({ offerId }) {
  required(MARKETPLACE_LATEST_PACKAGE_ID, "Marketplace package ID");
  required(offerId, "Offer ID");

  const tx = new Transaction();

  tx.moveCall({
    target:
      `${MARKETPLACE_LATEST_PACKAGE_ID}` +
      `::${MODULE}::reject_purchase_offer`,
    arguments: [tx.object(offerId)],
  });

  return tx;
}

export function withdrawAndRefundPurchaseOfferTx({
  offerId,
  escrowId,
}) {
  required(MARKETPLACE_LATEST_PACKAGE_ID, "Marketplace package ID");
  required(offerId, "Offer ID");

  const tx = new Transaction();

  tx.moveCall({
    target:
      `${MARKETPLACE_LATEST_PACKAGE_ID}` +
      `::${MODULE}::withdraw_purchase_offer`,
    arguments: [tx.object(offerId)],
  });

  addEscrowRefund(tx, escrowId);

  return tx;
}

export function refundRejectedPurchaseOfferTx({ escrowId }) {
  const tx = new Transaction();

  addEscrowRefund(tx, escrowId);

  return tx;
}
