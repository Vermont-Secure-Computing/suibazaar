import { useCallback, useEffect, useState } from 'react';
import { useCurrentAccount, useDAppKit } from '@mysten/dapp-kit-react';
import { getMerchantByAuthority } from '../lib/marketplaceData';
import { updateMerchantDepositTx, parsePercentToBps } from '../lib/sellerDepositSettings';

export default function SellerDepositSettings() {
  const account = useCurrentAccount();
  const dAppKit = useDAppKit();
  const [merchant, setMerchant] = useState(null);
  const [percent, setPercent] = useState('');
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState('');

  const reload = useCallback(async () => {
    if (!account?.address) { setMerchant(null); return; }
    try {
      const found = await getMerchantByAuthority(account.address);
      setMerchant(found);
      setPercent(found ? (Number(found.seller_deposit_bps ?? 0) / 100).toFixed(2) : '');
    } catch (err) { setMessage(err.message); }
  }, [account?.address]);

  useEffect(() => { reload(); }, [reload]);

  async function save(event) {
    event.preventDefault();
    try {
      if (!merchant) throw new Error('Merchant not found.');
      const bps = parsePercentToBps(percent);
      if (!window.confirm(`Update merchant seller security deposit to ${bps / 100}% for future orders?`)) return;
      setBusy(true); setMessage('Waiting for wallet confirmation...');
      const transaction = updateMerchantDepositTx({ merchant, percent });
      const result = await dAppKit.signAndExecuteTransaction({ transaction });
      if (result.FailedTransaction) throw new Error(result.FailedTransaction.status?.error?.message || 'Transaction failed.');
      setMessage(`Updated. Transaction: ${result.Transaction?.digest ?? 'submitted'}`);
      await reload();
    } catch (err) { setMessage(err.message || String(err)); }
    finally { setBusy(false); }
  }

  return (
    <main style={{ maxWidth: 680, margin: '30px auto', padding: 24 }}>
      <h1>Seller Security Deposit Settings</h1>
      {!account ? <p>Connect your seller wallet first.</p> : !merchant ? <p>No merchant profile found for this wallet.</p> : (
        <form onSubmit={save}>
          <p>Store: <strong>{merchant.store_name}</strong></p>
          <p>Current merchant rate: {Number(merchant.seller_deposit_bps ?? 0) / 100}%</p>
          <label htmlFor="seller-bps-percent">New seller security deposit (%)</label>
          <input id="seller-bps-percent" type="number" min="0" max="100" step="0.01" required value={percent} onChange={e => setPercent(e.target.value)} style={{ display: 'block', margin: '12px 0' }} />
          <p>Example: 10% of a 0.1 SUI order requires a 0.01 SUI seller deposit. Product-level overrides take precedence.</p>
          <button disabled={busy}>{busy ? 'Saving...' : 'Update Seller Deposit'}</button>
        </form>
      )}
      {message && <p role="status">{message}</p>}
    </main>
  );
}