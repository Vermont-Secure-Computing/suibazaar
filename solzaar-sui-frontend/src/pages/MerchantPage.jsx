import { useEffect, useState } from "react";
import { Link, useParams } from "react-router-dom";
import { useCurrentAccount, useDAppKit } from "@mysten/dapp-kit-react";
import {
  getMerchant,
  getProductsByMerchant,
  getMerchantReputation,
  getProductReviews,
  getSellerProductMessages,
} from "../lib/marketplaceData";
import { sendProductMessageTx } from "../lib/marketplace";
import "./MerchantPage.css";

export default function MerchantPage() {
  const { id } = useParams();

  const [merchant, setMerchant] = useState(null);
  const [products, setProducts] = useState([]);
  const [reputation, setReputation] = useState(null);
  const [productReviews, setProductReviews] = useState({});
  const [productsLoading, setProductsLoading] = useState(false);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [logoFailed, setLogoFailed] = useState(false);
  const [bannerFailed, setBannerFailed] = useState(false);
  const account = useCurrentAccount();
  const dAppKit = useDAppKit();

  const [sellerMessages, setSellerMessages] = useState([]);
  const [messagesLoading, setMessagesLoading] = useState(false);

  const [selectedConversation, setSelectedConversation] = useState(null);

  const [replyText, setReplyText] = useState("");
  const [replying, setReplying] = useState(false);
  const [replyStatus, setReplyStatus] = useState("");

  useEffect(() => {
    async function load() {
      try {
        setLoading(true);
        setError("");

        const result = await getMerchant(id);

        console.log("MERCHANT:", result);

        setMerchant(result);
        setProductsLoading(true);

        const [merchantProducts, merchantReputation] = await Promise.all([
          getProductsByMerchant(result.authority),
          getMerchantReputation(result.authority),
        ]);

        console.log("MERCHANT PRODUCTS:", merchantProducts);
        console.log("MERCHANT REPUTATION:", merchantReputation);

        const reviewEntries = await Promise.all(
          merchantProducts.map(async (product) => {
            try {
              const reviews = await getProductReviews(product.objectId);

              return [product.objectId, reviews];
            } catch (error) {
              console.error(
                `Failed to load reviews for product ${product.objectId}:`,
                error
              );

              return [product.objectId, []];
            }
          })
        );

        const reviewsByProduct = Object.fromEntries(reviewEntries);

        console.log("PRODUCT REVIEWS:", reviewsByProduct);

        setProducts(merchantProducts);
        setReputation(merchantReputation);
        setProductReviews(reviewsByProduct);
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

  useEffect(() => {
    if (
      !merchant?.authority ||
      !account?.address ||
      account.address.toLowerCase() !== merchant.authority.toLowerCase()
    ) {
      setSellerMessages([]);
      return;
    }

    let cancelled = false;

    async function loadMessages() {
      try {
        setMessagesLoading(true);

        const messages = await getSellerProductMessages(merchant.authority);

        if (!cancelled) {
          setSellerMessages(messages);
        }
      } catch (error) {
        console.error("Failed to load seller messages:", error);
      } finally {
        if (!cancelled) {
          setMessagesLoading(false);
        }
      }
    }

    loadMessages();

    return () => {
      cancelled = true;
    };
  }, [merchant?.authority, account?.address]);

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
  const totalReviews = Number(reputation?.total_reviews ?? 0);
  const totalRating = Number(reputation?.total_rating ?? 0);

  const averageRating = totalReviews > 0 ? totalRating / totalReviews : 0;

  const isStoreOwner =
    !!account?.address &&
    account.address.toLowerCase() === merchant.authority?.toLowerCase();

  const conversations = [];

  if (isStoreOwner) {
    const groups = new Map();

    for (const message of sellerMessages) {
      const productId = message.product?.toLowerCase();
      const buyer = message.buyer?.toLowerCase();

      if (!productId || !buyer) {
        continue;
      }

      const key = `${productId}:${buyer}`;

      if (!groups.has(key)) {
        groups.set(key, {
          key,
          productId: message.product,
          buyer: message.buyer,
          messages: [],
        });
      }

      groups.get(key).messages.push(message);
    }

    for (const conversation of groups.values()) {
      conversation.messages.sort(
        (a, b) => Number(a.created_at ?? 0) - Number(b.created_at ?? 0)
      );

      conversation.lastMessage =
        conversation.messages[conversation.messages.length - 1];

      conversation.product = products.find(
        (product) =>
          product.objectId?.toLowerCase() ===
          conversation.productId?.toLowerCase()
      );

      conversations.push(conversation);
    }

    conversations.sort(
      (a, b) =>
        Number(b.lastMessage?.created_at ?? 0) -
        Number(a.lastMessage?.created_at ?? 0)
    );
  }

  const ratingCounts = [
    {
      stars: 5,
      count: Number(reputation?.five_star ?? 0),
    },
    {
      stars: 4,
      count: Number(reputation?.four_star ?? 0),
    },
    {
      stars: 3,
      count: Number(reputation?.three_star ?? 0),
    },
    {
      stars: 2,
      count: Number(reputation?.two_star ?? 0),
    },
    {
      stars: 1,
      count: Number(reputation?.one_star ?? 0),
    },
  ];

  function renderStars(rating) {
    return Array.from({ length: 5 }, (_, index) =>
      index < Math.round(rating) ? "★" : "☆"
    ).join("");
  }

  async function sendSellerReply() {
    if (!selectedConversation || !account?.address) {
      return;
    }

    const text = replyText.trim();

    if (!text) {
      setReplyStatus("Enter a reply.");
      return;
    }

    if (new TextEncoder().encode(text).length > 280) {
      setReplyStatus("Reply must be 280 bytes or less.");
      return;
    }

    try {
      setReplying(true);
      setReplyStatus("");

      const tx = sendProductMessageTx({
        productId: selectedConversation.productId,

        // IMPORTANT:
        // seller reply must preserve the original buyer.
        buyer: selectedConversation.buyer,

        message: text,
      });

      const result = await dAppKit.signAndExecuteTransaction({
        transaction: tx,
      });

      if (result.FailedTransaction) {
        throw new Error(
          result.FailedTransaction.status?.error?.message ||
            "Failed to send reply."
        );
      }

      const digest = result.Transaction.digest;

      console.log("Seller reply transaction:", digest);

      setReplyText("");
      setReplyStatus("Reply sent.");

      const messages = await getSellerProductMessages(merchant.authority);

      setSellerMessages(messages);

      // Update currently-open conversation immediately.
      const refreshed = messages
        .filter(
          (message) =>
            message.product?.toLowerCase() ===
              selectedConversation.productId.toLowerCase() &&
            message.buyer?.toLowerCase() ===
              selectedConversation.buyer.toLowerCase()
        )
        .sort((a, b) => Number(a.created_at ?? 0) - Number(b.created_at ?? 0));

      setSelectedConversation((current) => ({
        ...current,
        messages: refreshed,
        lastMessage: refreshed[refreshed.length - 1] ?? current.lastMessage,
      }));
    } catch (error) {
      console.error("Seller reply error:", error);

      setReplyStatus(error?.message || "Failed to send reply.");
    } finally {
      setReplying(false);
    }
  }

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

              <div className="merchant-rating-summary">
                <span className="merchant-rating-stars">
                  {renderStars(averageRating)}
                </span>

                {totalReviews > 0 ? (
                  <>
                    <strong>{averageRating.toFixed(1)}</strong>
                    <span>
                      {totalReviews} {totalReviews === 1 ? "review" : "reviews"}
                    </span>
                  </>
                ) : (
                  <span>No reviews yet</span>
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

      {isStoreOwner && (
        <section className="merchant-messages">
          <div className="merchant-messages-heading">
            <div>
              <h2>Messages</h2>
              <p>Questions from buyers about your products</p>
            </div>

            {conversations.length > 0 && (
              <span className="merchant-message-count">
                {conversations.length}
              </span>
            )}
          </div>

          {messagesLoading ? (
            <div className="merchant-messages-empty">Loading messages...</div>
          ) : conversations.length === 0 ? (
            <div className="merchant-messages-empty">
              No buyer messages yet.
            </div>
          ) : (
            <div className="merchant-conversation-list">
              {conversations.map((conversation) => {
                const last = conversation.lastMessage;

                return (
                  <button
                    key={conversation.key}
                    type="button"
                    className="merchant-conversation-row"
                    onClick={() => {
                      setSelectedConversation(conversation);
                      setReplyStatus("");
                    }}
                  >
                    <div>
                      <strong>
                        {conversation.product?.title || "Product"}
                      </strong>

                      <span>
                        Buyer {conversation.buyer.slice(0, 6)}
                        ...
                        {conversation.buyer.slice(-4)}
                      </span>

                      <p>{last?.message}</p>
                    </div>

                    <span className="merchant-conversation-arrow">›</span>
                  </button>
                );
              })}
            </div>
          )}
        </section>
      )}

      <section className="merchant-reputation">
        <div className="merchant-reputation-heading">
          <div>
            <h2>Seller Reputation</h2>
            <p>Ratings from completed purchases</p>
          </div>

          <div className="merchant-reputation-score">
            {totalReviews > 0 ? (
              <>
                <strong>{averageRating.toFixed(1)}</strong>
                <span className="merchant-reputation-main-stars">
                  {renderStars(averageRating)}
                </span>
                <span>
                  {totalReviews} {totalReviews === 1 ? "review" : "reviews"}
                </span>
              </>
            ) : (
              <>
                <span className="merchant-reputation-main-stars">☆☆☆☆☆</span>
                <span>No reviews yet</span>
              </>
            )}
          </div>
        </div>

        <div className="merchant-rating-breakdown">
          {ratingCounts.map(({ stars, count }) => {
            const percentage =
              totalReviews > 0 ? (count / totalReviews) * 100 : 0;

            return (
              <div className="merchant-rating-row" key={stars}>
                <span className="merchant-rating-label">{stars} ★</span>

                <div className="merchant-rating-bar">
                  <div
                    className="merchant-rating-bar-fill"
                    style={{ width: `${percentage}%` }}
                  />
                </div>

                <span className="merchant-rating-count">{count}</span>
              </div>
            );
          })}
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

              const reviews = productReviews[product.objectId] ?? [];

              const productReviewCount = reviews.length;

              const productRatingTotal = reviews.reduce(
                (total, review) => total + Number(review.rating ?? 0),
                0
              );

              const productAverageRating =
                productReviewCount > 0
                  ? productRatingTotal / productReviewCount
                  : 0;

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

                    <div className="merchant-product-rating">
                      <span className="merchant-product-rating-stars">
                        {productReviewCount > 0
                          ? renderStars(productAverageRating)
                          : "☆☆☆☆☆"}
                      </span>

                      {productReviewCount > 0 ? (
                        <>
                          <strong>{productAverageRating.toFixed(1)}</strong>

                          <span>
                            {productReviewCount}{" "}
                            {productReviewCount === 1 ? "review" : "reviews"}
                          </span>
                        </>
                      ) : (
                        <span>No reviews yet</span>
                      )}
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
      {isStoreOwner && selectedConversation && (
        <div
          className="merchant-chat-overlay"
          onClick={() => setSelectedConversation(null)}
        >
          <div
            className="merchant-chat-panel"
            onClick={(event) => event.stopPropagation()}
          >
            <div className="merchant-chat-header">
              <div>
                <strong>
                  {selectedConversation.product?.title || "Product"}
                </strong>

                <span>
                  Buyer {selectedConversation.buyer.slice(0, 6)}
                  ...
                  {selectedConversation.buyer.slice(-4)}
                </span>
              </div>

              <button
                type="button"
                onClick={() => setSelectedConversation(null)}
                aria-label="Close conversation"
              >
                ×
              </button>
            </div>

            <div className="merchant-chat-messages">
              {selectedConversation.messages.map((message) => {
                const mine =
                  message.sender?.toLowerCase() ===
                  account.address.toLowerCase();

                return (
                  <div
                    key={message.objectId}
                    className={
                      mine
                        ? "merchant-chat-bubble mine"
                        : "merchant-chat-bubble theirs"
                    }
                  >
                    <strong>{mine ? "You" : "Buyer"}</strong>

                    <p>{message.message}</p>

                    <small>
                      {message.created_at
                        ? new Date(Number(message.created_at)).toLocaleString()
                        : ""}
                    </small>
                  </div>
                );
              })}
            </div>

            <div className="merchant-chat-compose">
              <textarea
                value={replyText}
                placeholder="Reply to buyer..."
                disabled={replying}
                onChange={(event) => setReplyText(event.target.value)}
              />

              <div className="merchant-chat-compose-footer">
                <small>
                  {new TextEncoder().encode(replyText).length}
                  {" / 280 bytes"}
                </small>

                <button
                  type="button"
                  onClick={sendSellerReply}
                  disabled={replying || !replyText.trim()}
                >
                  {replying ? "Sending..." : "Send"}
                </button>
              </div>

              {replyStatus && (
                <div className="merchant-chat-status">{replyStatus}</div>
              )}
            </div>
          </div>
        </div>
      )}
    </main>
  );
}
