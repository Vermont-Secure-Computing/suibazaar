import { useEffect, useState } from "react";
import {
  useCurrentAccount,
  useDAppKit,
} from "@mysten/dapp-kit-react";

import { createProductTx } from "../lib/marketplace";
import { getMerchantByAuthority } from "../lib/marketplaceData";

const MAX_IMAGES = 3;
const MAX_IMAGE_URI_BYTES = 250;

function utf8ByteLength(value) {
  return new TextEncoder().encode(
    String(value ?? "")
  ).length;
}

function FieldCounter({ value, maxBytes }) {
  const characters = String(value ?? "").length;
  const bytes = utf8ByteLength(value);
  const overLimit = bytes > maxBytes;

  return (
    <div
      style={{
        fontSize: 12,
        color: overLimit ? "#dc2626" : "#666",
        marginTop: 4,
      }}
    >
      {characters} characters · {bytes}/{maxBytes} bytes
      {overLimit ? " — too long" : ""}
    </div>
  );
}

export default function CreateProduct() {
  const account = useCurrentAccount();
  const dAppKit = useDAppKit();

  const [merchant, setMerchant] = useState(null);
  const [merchantLoading, setMerchantLoading] =
    useState(false);

  const [title, setTitle] = useState("");
  const [description, setDescription] = useState("");
  const [imageUris, setImageUris] = useState(
    Array(MAX_IMAGES).fill("")
  );
  const [category, setCategory] = useState("");
  const [price, setPrice] = useState("");
  const [stock, setStock] = useState("");

  const [submitting, setSubmitting] = useState(false);
  const [message, setMessage] = useState("");

  useEffect(() => {
    let cancelled = false;

    async function loadMerchant() {
      if (!account?.address) {
        setMerchant(null);
        return;
      }

      try {
        setMerchantLoading(true);
        setMessage("");

        const result = await getMerchantByAuthority(
          account.address
        );

        if (!cancelled) {
          setMerchant(result);
        }
      } catch (error) {
        console.error(
          "Failed to load merchant:",
          error
        );

        if (!cancelled) {
          setMerchant(null);
          setMessage(
            error?.message ||
              "Failed to load merchant profile."
          );
        }
      } finally {
        if (!cancelled) {
          setMerchantLoading(false);
        }
      }
    }

    loadMerchant();

    return () => {
      cancelled = true;
    };
  }, [account?.address]);

  const totalContentBytes =
    utf8ByteLength(title) +
    utf8ByteLength(description) +
    imageUris.reduce(
      (total, imageUri) =>
        total + utf8ByteLength(imageUri),
      0
    ) +
    utf8ByteLength(category);

  const transactionContentLimit = 500;

  const productTooLarge =
    totalContentBytes > transactionContentLimit;

  const updateImageUri = (index, value) => {
    setImageUris((current) =>
      current.map((imageUri, imageIndex) =>
        imageIndex === index ? value : imageUri
      )
    );
  };

  const createProduct = async () => {
    if (!account?.address) {
      setMessage("Connect wallet first.");
      return;
    }

    if (!merchant) {
      setMessage(
        "No active merchant profile found for this wallet."
      );
      return;
    }

    const cleanedTitle = title.trim();
    const cleanedDescription = description.trim();

    const cleanedImageUris = imageUris
      .map((imageUri) => imageUri.trim())
      .filter(Boolean);

    const cleanedCategory = category.trim();

    if (!cleanedTitle) {
      setMessage("Product name is required.");
      return;
    }

    if (!cleanedDescription) {
      setMessage("Description is required.");
      return;
    }

    if (!cleanedCategory) {
      setMessage("Category is required.");
      return;
    }

    const limits = [
      ["Product name", cleanedTitle, 64],
      ["Product description", cleanedDescription, 200],
      ["Category", cleanedCategory, 32],
    ];

    cleanedImageUris.forEach((imageUri, index) => {
      limits.push([
        `Image URL ${index + 1}`,
        imageUri,
        MAX_IMAGE_URI_BYTES,
      ]);
    });

    for (const [label, value, maxBytes] of limits) {
      const bytes = utf8ByteLength(value);

      if (bytes > maxBytes) {
        setMessage(
          `${label} must not exceed ${maxBytes} UTF-8 bytes. ` +
            `Current size: ${bytes} bytes.`
        );
        return;
      }
    }

    const cleanedTotalBytes = limits.reduce(
      (total, [, value]) =>
        total + utf8ByteLength(value),
      0
    );

    if (
      cleanedTotalBytes >
      transactionContentLimit
    ) {
      setMessage(
        `Product information is too large. ` +
          `Current content: ${cleanedTotalBytes} bytes. ` +
          `Recommended maximum: ${transactionContentLimit} bytes.`
      );
      return;
    }

    const priceNumber = Number(price);
    const stockNumber = Number(stock);

    if (
      !Number.isFinite(priceNumber) ||
      priceNumber <= 0
    ) {
      setMessage("Enter a valid price in SUI.");
      return;
    }

    if (
      !Number.isInteger(stockNumber) ||
      stockNumber < 0
    ) {
      setMessage(
        "Enter a valid whole-number stock quantity."
      );
      return;
    }

    /*
     * Same behavior as original Solzaar:
     * automatically generate product ID.
     */
    const productId = BigInt(Date.now());

    /*
     * 1 SUI = 1,000,000,000 MIST.
     *
     * Convert using the decimal string instead of
     * Number * 1e9 to avoid floating-point rounding.
     */
    const parts = price.trim().split(".");

    if (
      parts.length > 2 ||
      !/^\d+$/.test(parts[0] || "") ||
      (parts[1] && !/^\d+$/.test(parts[1]))
    ) {
      setMessage("Enter a valid price in SUI.");
      return;
    }

    const whole = parts[0] || "0";
    const fraction = parts[1] || "";

    if (fraction.length > 9) {
      setMessage(
        "SUI price can have at most 9 decimal places."
      );
      return;
    }

    const priceMist =
      BigInt(whole) * 1_000_000_000n +
      BigInt((fraction + "000000000").slice(0, 9));

    if (priceMist <= 0n) {
      setMessage(
        "Minimum price is 0.000000001 SUI."
      );
      return;
    }

    try {
      setSubmitting(true);
      setMessage(
        "Waiting for wallet confirmation..."
      );

      const tx = createProductTx({
        merchantId: merchant.objectId,
        productId,
        title: cleanedTitle,
        descriptionUri: cleanedDescription,
        imageUris: cleanedImageUris,
        category: cleanedCategory,
        priceMist,
        stock: stockNumber,
      });

      const result =
        await dAppKit.signAndExecuteTransaction({
          transaction: tx,
        });

      if (result.FailedTransaction) {
        throw new Error(
          result.FailedTransaction.status?.error
            ?.message || "Transaction failed"
        );
      }

      const digest = result.Transaction?.digest;

      setMessage(
        digest
          ? `Product created: ${digest}`
          : "Product created successfully."
      );

      setTitle("");
      setDescription("");
      setImageUris(
        Array(MAX_IMAGES).fill("")
      );
      setCategory("");
      setPrice("");
      setStock("");
    } catch (error) {
      console.error(
        "Create product error:",
        error
      );

      setMessage(
        error?.message ||
          "Failed to create product."
      );
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div
      style={{
        padding: 20,
        maxWidth: 700,
        margin: "0 auto",
        color: "#111827",
      }}
    >
      <h2>Create Product</h2>

      {!account && (
        <div
          style={{
            padding: 14,
            marginBottom: 20,
            border: "1px solid #ddd",
            borderRadius: 8,
            background: "#f9fafb",
          }}
        >
          Connect your wallet to create a product.
        </div>
      )}

      {account && merchantLoading && (
        <p>Loading merchant profile...</p>
      )}

      {account &&
        !merchantLoading &&
        !merchant && (
          <div
            style={{
              padding: 14,
              marginBottom: 20,
              border: "1px solid #f59e0b",
              borderRadius: 8,
              background: "#fffbeb",
              color: "#92400e",
            }}
          >
            No active merchant profile found for
            this wallet. Create a merchant profile
            first.
          </div>
        )}

      {merchant && (
        <div
          style={{
            padding: 14,
            marginBottom: 20,
            border: "1px solid #ddd",
            borderRadius: 8,
            background: "#f9fafb",
          }}
        >
          <strong>Store:</strong>{" "}
          {merchant.store_name || "Unnamed Store"}
        </div>
      )}

      <label>Product Name</label>
      <br />

      <input
        placeholder="Product Name"
        value={title}
        maxLength={64}
        onChange={(event) =>
          setTitle(event.target.value)
        }
      />

      <FieldCounter
        value={title}
        maxBytes={64}
      />

      <br />

      <label>Product Description</label>
      <br />

      <textarea
        placeholder="Describe the product, condition, size, materials, shipping details, and other important information."
        value={description}
        maxLength={200}
        rows={6}
        onChange={(event) =>
          setDescription(event.target.value)
        }
        style={{
          width: "100%",
          maxWidth: 600,
          padding: 10,
          boxSizing: "border-box",
          resize: "vertical",
          fontFamily: "inherit",
          fontSize: 14,
        }}
      />

      <FieldCounter
        value={description}
        maxBytes={200}
      />

      <br />

      <label>
        Product Images (optional, up to 3)
      </label>

      {imageUris.map((imageUri, index) => (
        <div
          key={index}
          style={{ marginTop: 10 }}
        >
          <input
            placeholder={`Image URL ${index + 1}`}
            value={imageUri}
            maxLength={MAX_IMAGE_URI_BYTES}
            onChange={(event) =>
              updateImageUri(
                index,
                event.target.value
              )
            }
          />

          <FieldCounter
            value={imageUri}
            maxBytes={MAX_IMAGE_URI_BYTES}
          />
        </div>
      ))}

      <br />

      <label>Category</label>
      <br />

      <input
        placeholder="Category"
        value={category}
        maxLength={32}
        onChange={(event) =>
          setCategory(event.target.value)
        }
      />

      <FieldCounter
        value={category}
        maxBytes={32}
      />

      <br />

      <label>Price in SUI</label>
      <br />

      <input
        type="number"
        min="0.000000001"
        step="0.000000001"
        placeholder="Price (SUI)"
        value={price}
        onChange={(event) =>
          setPrice(event.target.value)
        }
      />

      <div
        style={{
          fontSize: 12,
          color: "#666",
          marginTop: 4,
        }}
      >
        Minimum price: 0.000000001 SUI
      </div>

      <br />

      <label>Available Stock</label>
      <br />

      <input
        type="number"
        min="0"
        step="1"
        placeholder="Available Stock"
        value={stock}
        onChange={(event) =>
          setStock(event.target.value)
        }
      />

      <div
        style={{
          fontSize: 12,
          color: "#666",
          marginTop: 4,
        }}
      >
        Enter a whole number, such as 0, 1, 5,
        or 100.
      </div>

      <div
        style={{
          marginTop: 16,
          marginBottom: 16,
          padding: 12,
          maxWidth: 600,
          border: productTooLarge
            ? "1px solid #dc2626"
            : "1px solid #ddd",
          borderRadius: 8,
          background: productTooLarge
            ? "#fef2f2"
            : "#f9fafb",
          color: productTooLarge
            ? "#dc2626"
            : "#333",
        }}
      >
        <strong>
          Combined product content:
        </strong>{" "}
        {totalContentBytes}/
        {transactionContentLimit} recommended
        bytes

        {productTooLarge && (
          <div style={{ marginTop: 6 }}>
            Shorten the product description,
            image URL, or other fields before
            creating the product.
          </div>
        )}
      </div>

      <button
        type="button"
        onClick={createProduct}
        disabled={
          submitting ||
          productTooLarge ||
          !account ||
          !merchant ||
          merchantLoading
        }
      >
        {submitting
          ? "Creating..."
          : "Create Product"}
      </button>

      {message && (
        <p
          style={{
            marginTop: 16,
            maxWidth: 600,
            overflowWrap: "anywhere",
          }}
        >
          {message}
        </p>
      )}
    </div>
  );
}
