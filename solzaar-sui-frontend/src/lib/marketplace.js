import { Transaction } from "@mysten/sui/transactions";

import {
  MARKETPLACE_LATEST_PACKAGE_ID,
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

  const tx = new Transaction();

  tx.moveCall({
    target: `${MARKETPLACE_LATEST_PACKAGE_ID}::${MODULE}::create_merchant`,
    arguments: [
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