import { SuiGrpcClient } from "@mysten/sui/grpc";
import {
  MARKETPLACE_PACKAGE_ID,
  ESCROW_PACKAGE_ID,
  MODULE,
} from "../config";

const client = new SuiGrpcClient({
  network: "devnet",
  baseUrl: "https://fullnode.devnet.sui.io:443",
});

const MERCHANT_EVENT =
  `${MARKETPLACE_PACKAGE_ID}::${MODULE}::MerchantCreated`;

export async function getMerchants() {
  if (!MARKETPLACE_PACKAGE_ID) {
    throw new Error("VITE_MARKETPLACE_PACKAGE_ID is not set.");
  }

  const merchantIds = new Set();

  let page = await client.listEvents({
    filter: {
      eventType: MERCHANT_EVENT,
    },
    order: "descending",
    limit: 50,
  });

  while (true) {
    for (const event of page.events ?? []) {
      const id = event.json?.merchant_id;

      if (id) {
        merchantIds.add(id);
      }
    }

    if (!page.hasNextPage || !page.endCursor) {
      break;
    }

    page = await client.listEvents({
      filter: {
        eventType: MERCHANT_EVENT,
      },
      before: page.endCursor,
      limit: 50,
    });
  }

  const ids = [...merchantIds];

  if (ids.length === 0) {
    return [];
  }

  const result = await client.getObjects({
    objectIds: ids,
    include: {
      json: true,
    },
  });

  return (result.objects ?? [])
    .filter((object) => !(object instanceof Error))
    .map((object) => ({
      objectId: object.objectId,
      ...object.json,
    }))
    .filter((merchant) => merchant.active !== false);
}

export async function getMerchant(objectId) {
  const result = await client.getObject({
    objectId,
    include: {
      json: true,
    },
  });

  return {
    objectId: result.object.objectId,
    ...result.object.json,
  };
}

export async function getMerchantByOwner(owner) {
  if (!owner) return null;

  const type =
    `${MARKETPLACE_PACKAGE_ID}::${MODULE}::MerchantProfile`;

  const result = await client.listOwnedObjects({
    owner,
    type,
    include: {
      json: true,
    },
  });

  const object = (result.objects ?? []).find(
    (item) => item.json?.active !== false
  );

  if (!object) {
    return null;
  }

  return {
    objectId: object.objectId,
    ...object.json,
  };
}

export async function getProductsByMerchant(merchantAddress) {
  if (!merchantAddress) return [];

  const eventType =
    `${MARKETPLACE_PACKAGE_ID}::${MODULE}::ProductCreated`;

  const productIds = new Set();

  let page = await client.listEvents({
    filter: {
      eventType,
    },
    order: "descending",
    limit: 50,
  });

  while (true) {
    for (const event of page.events ?? []) {
      const data = event.json;

      if (
        data?.merchant?.toLowerCase() ===
        merchantAddress.toLowerCase()
      ) {
        if (data.product_object_id) {
          productIds.add(data.product_object_id);
        }
      }
    }

    if (!page.hasNextPage || !page.endCursor) {
      break;
    }

    page = await client.listEvents({
      filter: {
        eventType,
      },
      before: page.endCursor,
      limit: 50,
    });
  }

  const ids = [...productIds];

  if (ids.length === 0) {
    return [];
  }

  const result = await client.getObjects({
    objectIds: ids,
    include: {
      json: true,
    },
  });

  return (result.objects ?? [])
    .filter((object) => !(object instanceof Error))
    .map((object) => ({
      objectId: object.objectId,
      ...object.json,
    }))
    .filter(
      (product) =>
        product.deleted !== true &&
        product.active !== false
    );
}

export async function getProduct(objectId) {
  if (!objectId) {
    throw new Error("Product object ID is required.");
  }

  const result = await client.getObject({
    objectId,
    include: {
      json: true,
    },
  });

  return {
    objectId: result.object.objectId,
    ...result.object.json,
  };
}

export async function getMerchantByAuthority(authority) {
  if (!authority) return null;

  const merchants = await getMerchants();

  return (
    merchants.find(
      (merchant) =>
        merchant.authority?.toLowerCase() ===
        authority.toLowerCase()
    ) ?? null
  );
}

export async function getEscrowCreatedByDigest(
  digest
) {
  const eventType =
    `${ESCROW_PACKAGE_ID}::escrow::EscrowCreated`;

  const result = await client.listEvents({
    filter: {
      eventType,
    },
    order: "descending",
    limit: 50,
  });

  const event =
    (result.events ?? []).find(
      (item) =>
        item.transactionDigest === digest ||
        item.transaction?.digest === digest
    );

  if (!event?.json?.escrow_id) {
    throw new Error(
      "Escrow was created but its object ID could not be found."
    );
  }

  return event.json.escrow_id;
}
