import { Transaction } from "@mysten/sui/transactions";
import { MARKETPLACE_LATEST_PACKAGE_ID, MERCHANT_REGISTRY_ID, CLOCK_ID, MODULE } from "../config";

export function acceptPurchaseOfferTx({ merchantId, productId, offerId, escrowId }) {
  if (![merchantId, productId, offerId, escrowId].every(Boolean)) {
    throw new Error("Missing merchant, product, offer, or escrow ID.");
  }
  const tx = new Transaction();
  tx.moveCall({
    target: `${MARKETPLACE_LATEST_PACKAGE_ID}::${MODULE}::accept_purchase_offer`,
    arguments: [
      tx.object(MERCHANT_REGISTRY_ID),
      tx.object(merchantId),
      tx.object(productId),
      tx.object(offerId),
      tx.object(escrowId),
      tx.object(CLOCK_ID),
    ],
  });
  return tx;
}