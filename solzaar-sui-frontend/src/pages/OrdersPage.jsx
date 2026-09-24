import { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import { useCurrentAccount } from "@mysten/dapp-kit-react";

import {
  getBuyerOrderRecords,
  getSellerOrderRecords,
  getProduct,
  getMerchants,
} from "../lib/marketplaceData";

import {
  getMarketplaceEscrow,
  getEscrowStatusLabel,
  ESCROW_STATUS,
} from "../lib/escrow";

import "./OrdersPage.css";

const MIST_PER_SUI = 1_000_000_000n;

function mistToSui(value) {
  try {
    const mist = BigInt(value ?? 0);

    const whole = mist / MIST_PER_SUI;
    const fraction = mist % MIST_PER_SUI;

    return `${whole}.${fraction
      .toString()
      .padStart(9, "0")
      .slice(0, 4)}`;
  } catch {
    return "0.0000";
  }
}

function shortenAddress(address) {
  if (!address) return "Address unavailable";

  if (address.length <= 16) {
    return address;
  }

  return `${address.slice(0, 8)}...${address.slice(-6)}`;
}

function getProductImage(product) {
  const images =
    product?.image_uris ??
    product?.imageUris ??
    [];

  if (!Array.isArray(images)) {
    return "";
  }

  return images[0] ?? "";
}

export default function OrdersPage() {
  const account = useCurrentAccount();
  const navigate = useNavigate();

  const [buyerOrders, setBuyerOrders] =
    useState([]);

  const [sellerOrders, setSellerOrders] =
    useState([]);

  const [loading, setLoading] =
    useState(true);

  const [error, setError] =
    useState("");

  const enrichOrders = async (
    records,
    merchants
  ) => {
    return Promise.all(
      records.map(async (record) => {
        let escrow = null;
        let product = null;

        try {
          escrow =
            await getMarketplaceEscrow(
              record.escrow
            );
        } catch (escrowError) {
          console.error(
            "Escrow lookup error:",
            escrowError
          );
        }

        try {
          product = await getProduct(
            record.product
          );
        } catch (productError) {
          console.error(
            "Product lookup error:",
            productError
          );
        }

        const sellerMerchant =
          merchants.find(
            (merchant) =>
              merchant.authority
                ?.toLowerCase() ===
              record.seller
                ?.toLowerCase()
          ) ?? null;

        return {
          ...record,
          escrow,
          product,
          sellerMerchant,
        };
      })
    );
  };

  const loadOrders = async () => {
    if (!account?.address) {
      setBuyerOrders([]);
      setSellerOrders([]);
      setLoading(false);
      return;
    }

    try {
      setLoading(true);
      setError("");

      const [
        buyerRecords,
        sellerRecords,
        merchants,
      ] = await Promise.all([
        getBuyerOrderRecords(
          account.address
        ),
        getSellerOrderRecords(
          account.address
        ),
        getMerchants(),
      ]);

      const [
        enrichedBuyer,
        enrichedSeller,
      ] = await Promise.all([
        enrichOrders(
          buyerRecords,
          merchants
        ),
        enrichOrders(
          sellerRecords,
          merchants
        ),
      ]);

      setBuyerOrders(enrichedBuyer);
      setSellerOrders(enrichedSeller);
    } catch (loadError) {
      console.error(
        "Load orders error:",
        loadError
      );

      setError(
        loadError?.message ||
          "Failed to load orders."
      );
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadOrders();
  }, [account?.address]);

  if (!account?.address) {
    return (
      <main className="orders-page">
        <header className="orders-header">
          <h1>Orders</h1>
        </header>

        <div className="orders-state">
          Connect your wallet to view your
          purchases and seller orders.
        </div>
      </main>
    );
  }

  if (loading) {
    return (
      <main className="orders-page">
        <header className="orders-header">
          <h1>Orders</h1>
        </header>

        <div className="orders-state">
          Loading orders...
        </div>
      </main>
    );
  }

  return (
    <main className="orders-page">
      <header className="orders-header">
        <div>
          <h1>Orders</h1>

          <p>
            Manage your purchases and seller
            transactions.
          </p>
        </div>

        <button
          type="button"
          className="orders-refresh-button"
          onClick={loadOrders}
        >
          Refresh Orders
        </button>
      </header>

      {error && (
        <div className="orders-error">
          {error}
        </div>
      )}

      <section className="orders-section">
        <h2>
          My Purchases
          <span className="orders-count">
            {buyerOrders.length}
          </span>
        </h2>

        <OrderList
          orders={buyerOrders}
          role="buyer"
          onSelect={(order) =>
            navigate(
              `/orders/buyer/${order.escrow?.objectId ?? order.escrow}`
            )
          }
        />
      </section>

      <section className="orders-section">
        <h2>
          Seller Orders
          <span className="orders-count">
            {sellerOrders.length}
          </span>
        </h2>

        <OrderList
          orders={sellerOrders}
          role="seller"
          onSelect={(order) =>
            navigate(
              `/orders/seller/${order.escrow?.objectId ?? order.escrow}`
            )
          }
        />
      </section>
    </main>
  );
}

function OrderList({
  orders,
  role,
  onSelect,
}) {
  const [filter, setFilter] =
    useState("all");

  const filteredOrders =
    orders.filter((order) => {
      const status =
        order.escrow?.status;

      if (filter === "active") {
        return (
          status !==
            ESCROW_STATUS.COMPLETED &&
          status !==
            ESCROW_STATUS.CANCELLED
        );
      }

      if (filter === "completed") {
        return (
          status ===
          ESCROW_STATUS.COMPLETED
        );
      }

      if (filter === "needs-action") {
        if (role === "seller") {
          return (
            status ===
              ESCROW_STATUS.CREATED &&
            BigInt(
              order.escrow
                ?.depositedA ?? 0
            ) > 0n &&
            BigInt(
              order.escrow
                ?.depositedB ?? 0
            ) === 0n
          );
        }

        if (role === "buyer") {
          return (
            status ===
            ESCROW_STATUS
              .FINALIZATION_SUGGESTED
          );
        }
      }

      return true;
    });

  if (orders.length === 0) {
    return (
      <div className="orders-empty">
        {role === "buyer"
          ? "No purchase orders yet."
          : "No seller orders yet."}
      </div>
    );
  }

  return (
    <>
      <div className="orders-controls">
        <label>
          Filter

          <select
            value={filter}
            onChange={(event) =>
              setFilter(
                event.target.value
              )
            }
          >
            <option value="all">
              All Orders
            </option>

            <option value="needs-action">
              Needs Action
            </option>

            <option value="active">
              Active
            </option>

            <option value="completed">
              Completed
            </option>
          </select>
        </label>
      </div>

      {filteredOrders.length === 0 ? (
        <div className="orders-empty">
          No matching orders.
        </div>
      ) : (
        <div className="orders-list">
          {filteredOrders.map(
            (order) => (
              <OrderRow
                key={order.objectId}
                order={order}
                role={role}
                onSelect={() =>
                  onSelect(order)
                }
              />
            )
          )}
        </div>
      )}
    </>
  );
}

function OrderRow({
  order,
  role,
  onSelect,
}) {
  const escrow = order.escrow;
  const product = order.product;
  const merchant =
    order.sellerMerchant;

  const image =
    getProductImage(product);

  const status =
    escrow?.status ?? -1;

  let needsAction = false;

  if (role === "seller") {
    needsAction =
      status ===
        ESCROW_STATUS.CREATED &&
      BigInt(
        escrow?.depositedA ?? 0
      ) > 0n &&
      BigInt(
        escrow?.depositedB ?? 0
      ) === 0n;
  }

  if (role === "buyer") {
    needsAction =
      status ===
      ESCROW_STATUS
        .FINALIZATION_SUGGESTED;
  }

  return (
    <button
      type="button"
      className="order-row"
      onClick={onSelect}
    >
      <div className="order-product">
        {image ? (
          <img
            src={image}
            alt={
              product?.title ||
              "Product"
            }
          />
        ) : (
          <div className="order-image-placeholder">
            No image
          </div>
        )}

        <div>
          <strong>
            {product?.title ||
              "Product"}
          </strong>

          <span>
            {merchant?.store_name ||
              shortenAddress(
                order.seller
              )}
          </span>

          <small>
            Qty {order.quantity}
          </small>
        </div>
      </div>

      <div className="order-value">
        <small>Order value</small>

        <strong>
          {mistToSui(
            order.total_price
          )}{" "}
          SUI
        </strong>
      </div>

      <div className="order-status">
        {needsAction && (
          <span className="order-action-badge">
            Action needed
          </span>
        )}

        <span
          className={`order-status-badge status-${status}`}
        >
          {escrow
            ? getEscrowStatusLabel(
                status
              )
            : "Escrow unavailable"}
        </span>
      </div>

      <span className="order-arrow">
        ›
      </span>
    </button>
  );
}