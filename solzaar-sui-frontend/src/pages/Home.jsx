import { useState } from "react";
import MerchantList from "./MerchantList";

export default function Home() {
  const [search, setSearch] = useState("");

  return (
    <main
      style={{
        maxWidth: 1200,
        margin: "0 auto",
        padding: "40px 20px",
      }}
    >
      <section style={{ marginBottom: 36 }}>
        <h1>Shop from Sui merchants</h1>

        <p>
          Discover stores, view products, and buy directly
          from sellers on Solzaar.
        </p>
      </section>

      <section>
        <input
          type="search"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          placeholder="Search merchants..."
          style={{
            width: "100%",
            padding: "14px 16px",
            borderRadius: 10,
            border: "1px solid #d1d5db",
            fontSize: 16,
          }}
        />

        <MerchantList search={search} />
      </section>
    </main>
  );
}
