import { Transaction, coinWithBalance } from "@mysten/sui/transactions";

import {
  MARKETPLACE_LATEST_PACKAGE_ID,
  MERCHANT_REGISTRY_ID,
  ESCROW_LATEST_PACKAGE_ID,
  CLOCK_ID,
  MODULE,
} from "../config";

const ESCROW_MODULE = "escrow";

export function calculateOrderAmounts({ price, quantity, sellerDepositBps }) {
  const unitPrice = BigInt(price);
  const qty = BigInt(quantity);

  const totalPrice = unitPrice * qty;

  let securityDeposit = (totalPrice * BigInt(sellerDepositBps)) / 10_000n;

  if (securityDeposit === 0n) {
    securityDeposit = 1n;
  }

  const buyerDeposit = totalPrice + securityDeposit;

  return {
    totalPrice,
    securityDeposit,
    buyerDeposit,
  };
}

/*
 * TX 1:
 * Create shared escrow using latest Escrow implementation.
 */
export function createEscrowTx({
  buyer,
  seller,
  totalPrice,
  buyerDeposit,
  securityDeposit,
  productId,
}) {
  const tx = new Transaction();

  const note = JSON.stringify({
    marketplace: "solbazaar",
    product: productId,
  });

  tx.moveCall({
    target: `${ESCROW_LATEST_PACKAGE_ID}::${ESCROW_MODULE}::create_escrow`,

    arguments: [
      tx.pure.u8(0),

      tx.pure.option("address", buyer),

      tx.pure.option("address", seller),

      tx.pure.u64(totalPrice),

      tx.pure.u64(buyerDeposit),

      tx.pure.u64(securityDeposit),

      tx.pure.vector("u8", Array.from(new TextEncoder().encode(note))),

      tx.object(CLOCK_ID),
    ],
  });

  return tx;
}

/*
 * TX 2:
 *
 * 1. Deposit buyer funds into Escrow V2
 * 2. Create OrderRecord through Marketplace V2
 * 3. Reserve product stock
 */
export function createBuyerOrderTx({
  escrowId,
  merchantId,
  productId,
  quantity,
  buyerDeposit,
}) {
  const tx = new Transaction();

  const depositCoin = coinWithBalance({
    balance: buyerDeposit,
  });

  // Deposit buyer funds into escrow
  tx.moveCall({
    target:
      `${ESCROW_LATEST_PACKAGE_ID}::${ESCROW_MODULE}::deposit`,

    arguments: [
      tx.object(escrowId),
      depositCoin,
      tx.object(CLOCK_ID),
    ],
  });

  // Create protected order record and reserve stock
  tx.moveCall({
    target:
      `${MARKETPLACE_LATEST_PACKAGE_ID}::${MODULE}::create_order_record_v2`,

    arguments: [
      tx.object(MERCHANT_REGISTRY_ID),
      tx.object(merchantId),
      tx.object(productId),
      tx.object(escrowId),
      tx.pure.u32(Number(quantity)),
      tx.object(CLOCK_ID),
    ],
  });

  return tx;
}


export function createBuyerPurchaseOfferTx({
  escrowId,
  merchantId,
  productId,
  unitPriceMist,
  quantity,
  expiresAt,
  buyerDeposit,
}) {
  const tx = new Transaction();

  const depositCoin = coinWithBalance({
    balance: BigInt(buyerDeposit),
  });

  // Fund the escrow first.
  tx.moveCall({
    target: `${ESCROW_LATEST_PACKAGE_ID}::${ESCROW_MODULE}::deposit`,
    arguments: [
      tx.object(escrowId),
      depositCoin,
      tx.object(CLOCK_ID),
    ],
  });

  // Create the buyer-funded purchase offer.
  tx.moveCall({
    target: `${MARKETPLACE_LATEST_PACKAGE_ID}::${MODULE}::create_purchase_offer`,
    arguments: [
      tx.object(merchantId),
      tx.object(productId),
      tx.object(escrowId),
      tx.pure.u64(BigInt(unitPriceMist)),
      tx.pure.u32(Number(quantity)),
      tx.pure.u64(BigInt(expiresAt)),
      tx.object(CLOCK_ID),
    ],
  });

  return tx;
}


