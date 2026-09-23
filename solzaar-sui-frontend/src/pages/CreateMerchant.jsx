import { useState } from "react";
import {
  useCurrentAccount,
  useDAppKit,
} from "@mysten/dapp-kit-react";

import { createMerchantTx } from "../lib/marketplace";

const box = {
  maxWidth: 720,
  margin: "30px auto",
  padding: 24,
};

const field = {
  display: "grid",
  gap: 6,
  marginBottom: 14,
};

export default function CreateMerchant() {
  const account = useCurrentAccount();
  const dAppKit = useDAppKit();

  const [msg, setMsg] = useState("");
  const [busy, setBusy] = useState(false);

  const [f, setF] = useState({
    storeName: "",
    descriptionUri: "",
    logoUri: "",
    bannerUri: "",
    shipsFrom: "",
    preferredContact: "",
    sellerDepositBps: "1000",
  });

  const set = (key, value) => {
    setF({
      ...f,
      [key]: value,
    });
  };

  async function go(e) {
    e.preventDefault();

    if (!account) {
      setMsg("Connect your wallet first.");
      return;
    }

    try {
      setBusy(true);
      setMsg("Waiting for wallet confirmation...");

      const result = await dAppKit.signAndExecuteTransaction({
        transaction: createMerchantTx(f),
      });

      if (result.FailedTransaction) {
        throw new Error(
          result.FailedTransaction.status?.error?.message ||
            "Transaction failed"
        );
      }

      const digest = result.Transaction?.digest;

      setMsg(
        digest
          ? `Success: ${digest}`
          : "Transaction submitted successfully."
      );
    } catch (error) {
      console.error(error);
      setMsg(error?.message || String(error));
    } finally {
      setBusy(false);
    }
  }

  const fields = {
    storeName: "Store name",
    descriptionUri: "Description URI",
    logoUri: "Logo URI",
    bannerUri: "Banner URI",
    shipsFrom: "Ships from",
    preferredContact: "Preferred contact",
    sellerDepositBps: "Seller deposit BPS",
  };

  return (
    <form onSubmit={go} style={box}>
      <h1>Create Merchant</h1>

      {Object.entries(fields).map(([key, label]) => (
        <label style={field} key={key}>
          {label}

          <input
            value={f[key]}
            onChange={(e) => set(key, e.target.value)}
          />
        </label>
      ))}

      <button disabled={!account || busy}>
        {busy ? "Creating..." : "Create Merchant"}
      </button>

      <p>{msg}</p>
    </form>
  );
}
