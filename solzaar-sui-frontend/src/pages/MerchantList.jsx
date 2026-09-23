import { useEffect, useMemo, useState } from "react";
import { Link } from "react-router-dom";
import { getMerchants } from "../lib/marketplaceData";
import "./MerchantList.css";

export default function MerchantList({ search = "" }) {
  const [merchants, setMerchants] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [failedLogos, setFailedLogos] = useState({});

  useEffect(() => {
    async function load() {
      try {
        setLoading(true);
        setError("");

        const result = await getMerchants();

        console.log("PUBLIC MERCHANTS:", result);

        setMerchants(result);
      } catch (err) {
        console.error(err);
        setError(err?.message || String(err));
      } finally {
        setLoading(false);
      }
    }

    load();
  }, []);

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase();

    if (!q) return merchants;

    return merchants.filter((merchant) =>
      [
        merchant.store_name,
        merchant.description_uri,
        merchant.ships_from,
      ]
        .filter(Boolean)
        .some((value) =>
          String(value).toLowerCase().includes(q)
        )
    );
  }, [merchants, search]);

  if (loading) {
    return <p className="merchant-status">Loading merchants...</p>;
  }

  if (error) {
    return (
      <p className="merchant-status merchant-error">
        {error}
      </p>
    );
  }

  if (filtered.length === 0) {
    return (
      <p className="merchant-status">
        No merchants found.
      </p>
    );
  }

  return (
    <div className="merchant-grid">
      {filtered.map((merchant) => {
        const logoFailed = failedLogos[merchant.objectId];

        const initial =
          (merchant.store_name || "S")
            .slice(0, 1)
            .toUpperCase();

        return (
          <article
            className="merchant-card"
            key={merchant.objectId}
          >
            <div className="merchant-card-header">
              <div className="merchant-avatar">
                {merchant.logo_uri && !logoFailed ? (
                  <img
                    src={merchant.logo_uri}
                    alt={`${merchant.store_name || "Merchant"} logo`}
                    onError={() =>
                      setFailedLogos((current) => ({
                        ...current,
                        [merchant.objectId]: true,
                      }))
                    }
                  />
                ) : (
                  <span>{initial}</span>
                )}
              </div>

              <div>
                <div className="merchant-name-row">
                  <h3>
                    {merchant.store_name || "Unnamed Store"}
                  </h3>

                  {merchant.verified && (
                    <span className="merchant-verified">
                      Verified
                    </span>
                  )}
                </div>

                <span className="merchant-location">
                  Ships from{" "}
                  {merchant.ships_from || "Not specified"}
                </span>
              </div>
            </div>

            <p className="merchant-description">
              {merchant.description_uri ||
                "No store description provided."}
            </p>

            <div className="merchant-info">
              <span>
                {Number(merchant.total_sold ?? 0)} items sold
              </span>

              <span>
                Seller deposit:{" "}
                {Number(merchant.seller_deposit_bps ?? 0) / 100}%
              </span>
            </div>

            <Link
              className="merchant-visit-link"
              to={`/merchant/${merchant.objectId}`}
            >
              Visit Store
            </Link>
          </article>
        );
      })}
    </div>
  );
}
