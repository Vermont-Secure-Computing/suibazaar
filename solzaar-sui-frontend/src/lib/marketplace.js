import { Transaction } from "@mysten/sui/transactions";

import {
  MARKETPLACE_LATEST_PACKAGE_ID,
  MERCHANT_REGISTRY_ID,
  MODULE,
  CLOCK_ID,
} from "../config";

const need = () => {
  if (!MARKETPLACE_LATEST_PACKAGE_ID) {
    throw new Error(
      "Set VITE_MARKETPLACE_LATEST_PACKAGE_ID to the latest Devnet package ID."
    );
  }
};

export function createMerchantTx(f) {
  need();

  if (!MERCHANT_REGISTRY_ID) {
    throw new Error(
      "Set VITE_MERCHANT_REGISTRY_ID to the Devnet MerchantRegistry object ID."
    );
  }

  const tx = new Transaction();

  tx.moveCall({
    target: `${MARKETPLACE_LATEST_PACKAGE_ID}::${MODULE}::create_merchant`,
    arguments: [
      tx.object(MERCHANT_REGISTRY_ID),
      tx.pure.string(f.storeName),
      tx.pure.string(f.descriptionUri),
      tx.pure.string(f.logoUri),
      tx.pure.string(f.bannerUri),
      tx.pure.string(f.shipsFrom),
      tx.pure.u16(Number(f.sellerDepositBps)),
      tx.pure.string(f.preferredContact),
      tx.object(CLOCK_ID),
    ],
  });

  return tx;
}

export function createProductTx(f) {
  need();

  const tx = new Transaction();

  tx.moveCall({
    target: `${MARKETPLACE_LATEST_PACKAGE_ID}::${MODULE}::create_product`,
    arguments: [
      tx.object(f.merchantId),
      tx.pure.u64(BigInt(f.productId)),
      tx.pure.string(f.title),
      tx.pure.string(f.descriptionUri),
      tx.pure.vector("string", f.imageUris),
      tx.pure.string(f.category),
      tx.pure.u64(BigInt(f.priceMist)),
      tx.pure.u32(Number(f.stock)),
      tx.object(CLOCK_ID),
    ],
  });

  return tx;
}

export function submitReviewTx({
  merchantId,
  productId,
  orderId,
  escrowId,
  reputationId,
  rating,
  comment,
}) {
  need();

  if (!merchantId) {
    throw new Error("Merchant object ID is required.");
  }

  if (!productId) {
    throw new Error("Product object ID is required.");
  }

  if (!orderId) {
    throw new Error("Order object ID is required.");
  }

  if (!escrowId) {
    throw new Error("Escrow object ID is required.");
  }

  if (!reputationId) {
    throw new Error("Merchant reputation object ID is required.");
  }

  const numericRating = Number(rating);

  if (
    !Number.isInteger(numericRating) ||
    numericRating < 1 ||
    numericRating > 5
  ) {
    throw new Error("Rating must be between 1 and 5.");
  }

  const reviewComment = String(comment ?? "");

  if (new TextEncoder().encode(reviewComment).length > 280) {
    throw new Error("Review comment must be 280 bytes or less.");
  }

  const tx = new Transaction();

  tx.moveCall({
    target:
      `${MARKETPLACE_LATEST_PACKAGE_ID}` +
      `::${MODULE}::submit_review`,

    arguments: [
      tx.object(merchantId),
      tx.object(productId),
      tx.object(orderId),
      tx.object(escrowId),
      tx.object(reputationId),
      tx.pure.u8(numericRating),
      tx.pure.string(reviewComment),
      tx.object(CLOCK_ID),
    ],
  });

  return tx;
}