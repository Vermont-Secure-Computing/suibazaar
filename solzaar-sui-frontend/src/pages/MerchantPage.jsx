import { useEffect, useState } from "react";
import { Link, useParams } from "react-router-dom";
import { getMerchant, getProductsByMerchant } from "../lib/marketplaceData";
import "./MerchantPage.css";

export default function MerchantPage() {
  const { id } = useParams();

  const [merchant, setMerchant] = useState(null);
  const [products, setProducts] = useState([]);
  const [productsLoading, setProductsLoading] = useState(false);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [logoFailed, setLogoFailed] = useState(false);
  const [bannerFailed, setBannerFailed] = useState(false);

  useEffect(() => {
    async function load() {
      try {
        setLoading(true);
        setError("");

        const result = await getMerchant(id);

        console.log("MERCHANT:", result);

        setMerchant(result);
        setProductsLoading(true);

        const merchantProducts = await getProductsByMerchant(result.authority);

        console.log("MERCHANT PRODUCTS:", merchantProducts);

        setProducts(merchantProducts);
        setProductsLoading(false);
      } catch (err) {
        console.error(err);
        setError(err?.message || String(err));
      } finally {
        setLoading(false);
      }
    }

    if (id) {
      load();
    }
  }, [id]);

  if (loading) {
    return (
      <main className="merchant-page">
        <p>Loading store...</p>
      </main>
    );
  }

  if (error) {
    return (
      <main className="merchant-page">
        <Link to="/" className="merchant-back">
          ← Back to Marketplace
        </Link>

        <div className="merchant-page-error">{error}</div>
      </main>
    );
  }

  if (!merchant) {
    return (
      <main className="merchant-page">
        <p>Merchant not found.</p>
      </main>
    );
  }

  const initial = (merchant.store_name || "S").slice(0, 1).toUpperCase();

  const sellerDeposit = Number(merchant.seller_deposit_bps ?? 0) / 100;

  return (
    <main className="merchant-page">
      <Link to="/" className="merchant-back">
        ← Back to Marketplace
      </Link>

      <section className="merchant-store">
        <div className="merchant-banner">
          {merchant.banner_uri && !bannerFailed ? (
            <img
              src={merchant.banner_uri}
              alt=""
              onError={() => setBannerFailed(true)}
            />
          ) : (
            <div className="merchant-banner-placeholder" />
          )}
        </div>

        <div className="merchant-store-content">
          <div className="merchant-store-header">
            <div className="merchant-store-avatar">
              {merchant.logo_uri && !logoFailed ? (
                <img
                  src={merchant.logo_uri}
                  alt={`${merchant.store_name || "Merchant"} logo`}
                  onError={() => setLogoFailed(true)}
                />
              ) : (
                <span>{initial}</span>
              )}
            </div>

            <div className="merchant-store-title">
              <div className="merchant-store-name">
                <h1>{merchant.store_name || "Unnamed Store"}</h1>

                {merchant.verified && (
                  <span className="merchant-page-verified">Verified</span>
                )}
              </div>

              <p>
                Ships from{" "}
                <strong>{merchant.ships_from || "Not specified"}</strong>
              </p>
            </div>
          </div>

          <p className="merchant-store-description">
            {merchant.description_uri || "No store description provided."}
          </p>

          <div className="merchant-store-stats">
            <div>
              <strong>{Number(merchant.total_sold ?? 0)}</strong>
              <span>Items sold</span>
            </div>

            <div>
              <strong>{sellerDeposit}%</strong>
              <span>Seller deposit</span>
            </div>

            <div>
              <strong>{merchant.active ? "Active" : "Inactive"}</strong>
              <span>Store status</span>
            </div>
          </div>

          {merchant.preferred_contact && (
            <div className="merchant-contact">
              <span>Preferred contact</span>
              <strong>{merchant.preferred_contact}</strong>
            </div>
          )}
        </div>
      </section>

      <section className="merchant-products">
        <div className="merchant-products-heading">
          <div>
            <h2>Products</h2>
            <p>Products from {merchant.store_name}</p>
          </div>
        </div>

        {productsLoading ? (
          <div className="merchant-products-empty">Loading products...</div>
        ) : products.length === 0 ? (
          <div className="merchant-products-empty">No products yet.</div>
        ) : (
          <div className="product-grid">
            {products.map((product) => {
              const priceSui = Number(product.price ?? 0) / 1_000_000_000;

              const image = product.image_uris?.[0] || "";

              return (
                <article className="product-card" key={product.objectId}>
                  <div className="product-image">
                    {image ? (
                      <img src={image} alt={product.title} />
                    ) : (
                      <div className="product-no-image">No image</div>
                    )}
                  </div>

                  <div className="product-card-body">
                    <span className="product-category">{product.category}</span>

                    <h3>{product.title}</h3>

                    <p className="product-description">
                      {product.description_uri}
                    </p>

                    <div className="product-price">
                      {priceSui.toLocaleString(undefined, {
                        maximumFractionDigits: 9,
                      })}{" "}
                      SUI
                    </div>

                    <div className="product-stock">
                      {Number(product.stock ?? 0)} in stock
                    </div>

                    <Link
                      to={`/product/${product.objectId}`}
                      className="product-view-button"
                    >
                      View Product
                    </Link>
                  </div>
                </article>
              );
            })}
          </div>
        )}
      </section>
    </main>
  );
}
