import { Transaction, coinWithBalance } from "@mysten/sui/transactions";
import { MARKETPLACE_LATEST_PACKAGE_ID, MERCHANT_REGISTRY_ID, ESCROW_LATEST_PACKAGE_ID, CLOCK_ID, MODULE } from "../config";

const MAX_U64 = (1n << 64n) - 1n;
const MAX_U32 = (1n << 32n) - 1n;
const ESCROW_MODULE = "escrow";
function requireConfig() {
  for (const [name, value] of Object.entries({ MARKETPLACE_LATEST_PACKAGE_ID, MERCHANT_REGISTRY_ID, ESCROW_LATEST_PACKAGE_ID, CLOCK_ID, MODULE })) {
    if (!value) throw new Error(`Missing configuration: ${name}`);
  }
}
function unsigned(value, label, max = MAX_U64, allowZero = false) {
  let n;
  try { n = BigInt(value); } catch { throw new Error(`${label} must be an integer.`); }
  if (n < (allowZero ? 0n : 1n) || n > max) throw new Error(`${label} is outside the valid range.`);
  return n;
}
function mul(a, b, label) {
  if (a > MAX_U64 / b) throw new Error(`${label} exceeds Sui u64 range.`);
  return a * b;
}
export function calculateOrderAmounts({ price, quantity, sellerDepositBps }) {
  const unitPrice = unsigned(price, "Unit price");
  const qty = unsigned(quantity, "Quantity", MAX_U32);
  const bps = unsigned(sellerDepositBps, "Seller deposit BPS", 10000n, true);
  const totalPrice = mul(unitPrice, qty, "Order total");
  const numerator = bps === 0n ? 0n : mul(totalPrice, bps, "Deposit numerator");
  let securityDeposit = numerator / 10000n;
  if (securityDeposit === 0n) securityDeposit = 1n; // Matches marketplace Move contract, including 0 BPS.
  if (totalPrice > MAX_U64 - securityDeposit) throw new Error("Buyer deposit exceeds Sui u64 range.");
  return { totalPrice, securityDeposit, buyerDeposit: totalPrice + securityDeposit };
}
export function createEscrowTx({ buyer, seller, totalPrice, buyerDeposit, securityDeposit, productId }) {
  requireConfig();
  if (!buyer || !seller || !productId) throw new Error("Buyer, seller and product ID are required.");
  if (buyer.toLowerCase() === seller.toLowerCase()) throw new Error("Buyer and seller must differ.");
  const total = unsigned(totalPrice, "Total price");
  const security = unsigned(securityDeposit, "Seller deposit");
  const buyerFunds = unsigned(buyerDeposit, "Buyer deposit");
  if (total > MAX_U64 - security || buyerFunds !== total + security) throw new Error("Escrow deposit amounts are inconsistent.");
  const tx = new Transaction();
  const note = JSON.stringify({ marketplace: "solbazaar", product: productId });
  tx.moveCall({ target: `${ESCROW_LATEST_PACKAGE_ID}::${ESCROW_MODULE}::create_escrow`, arguments: [
    tx.pure.u8(0), tx.pure.option("address", buyer), tx.pure.option("address", seller),
    tx.pure.u64(total), tx.pure.u64(buyerFunds), tx.pure.u64(security),
    tx.pure.vector("u8", Array.from(new TextEncoder().encode(note))), tx.object(CLOCK_ID),
  ] });
  return tx;
}
export function createBuyerOrderTx({ escrowId, merchantId, productId, quantity, buyerDeposit }) {
  requireConfig();
  if (!escrowId || !merchantId || !productId) throw new Error("Missing escrow, merchant or product ID.");
  const qty = unsigned(quantity, "Quantity", MAX_U32);
  const funds = unsigned(buyerDeposit, "Buyer deposit");
  const tx = new Transaction();
  const coin = coinWithBalance({ balance: funds });
  tx.moveCall({ target: `${ESCROW_LATEST_PACKAGE_ID}::${ESCROW_MODULE}::deposit`, arguments: [tx.object(escrowId), coin, tx.object(CLOCK_ID)] });
  tx.moveCall({ target: `${MARKETPLACE_LATEST_PACKAGE_ID}::${MODULE}::create_order_record_v2`, arguments: [
    tx.object(MERCHANT_REGISTRY_ID), tx.object(merchantId), tx.object(productId), tx.object(escrowId), tx.pure.u32(Number(qty)), tx.object(CLOCK_ID),
  ] });
  return tx;
}
export function createBuyerPurchaseOfferTx({ escrowId, merchantId, productId, unitPriceMist, quantity, buyerDeposit }) {
  requireConfig();
  if (!escrowId || !merchantId || !productId) throw new Error("Missing escrow, merchant or product ID.");
  const price = unsigned(unitPriceMist, "Offer unit price");
  const qty = unsigned(quantity, "Quantity", MAX_U32);
  const funds = unsigned(buyerDeposit, "Buyer deposit");
  const tx = new Transaction();
  const coin = coinWithBalance({ balance: funds });
  tx.moveCall({ target: `${ESCROW_LATEST_PACKAGE_ID}::${ESCROW_MODULE}::deposit`, arguments: [tx.object(escrowId), coin, tx.object(CLOCK_ID)] });
  tx.moveCall({ target: `${MARKETPLACE_LATEST_PACKAGE_ID}::${MODULE}::create_purchase_offer`, arguments: [
    tx.object(merchantId), tx.object(productId), tx.object(escrowId), tx.pure.u64(price), tx.pure.u32(Number(qty)), tx.object(CLOCK_ID),
  ] });
  return tx;
}