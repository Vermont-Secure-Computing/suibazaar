import { Transaction } from '@mysten/sui/transactions';
import { MARKETPLACE_LATEST_PACKAGE_ID, MODULE } from '../config';

export function parsePercentToBps(value) {
  const text = String(value ?? '').trim();
  if (!/^(?:\d{1,3})(?:\.\d{1,2})?$/.test(text)) throw new Error('Enter a percentage with at most 2 decimals.');
  const [whole, frac = ''] = text.split('.');
  const bps = Number(whole) * 100 + Number(frac.padEnd(2, '0'));
  if (bps < 0 || bps > 10000) throw new Error('Seller deposit must be between 0% and 100%.');
  return bps;
}

export function updateMerchantDepositTx({ merchant, percent }) {
  if (!MARKETPLACE_LATEST_PACKAGE_ID || !merchant?.objectId) throw new Error('Missing marketplace package or merchant object.');
  const bps = parsePercentToBps(percent);
  const tx = new Transaction();
  tx.moveCall({
    target: `${MARKETPLACE_LATEST_PACKAGE_ID}::${MODULE}::update_merchant`,
    arguments: [
      tx.object(merchant.objectId),
      tx.pure.string(merchant.store_name ?? ''),
      tx.pure.string(merchant.description_uri ?? ''),
      tx.pure.string(merchant.logo_uri ?? ''),
      tx.pure.string(merchant.banner_uri ?? ''),
      tx.pure.string(merchant.ships_from ?? ''),
      tx.pure.u16(bps),
      tx.pure.string(merchant.preferred_contact ?? ''),
      tx.pure.bool(merchant.active === true),
    ],
  });
  return tx;
}