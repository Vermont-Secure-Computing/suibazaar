export const MARKETPLACE_PACKAGE_ID =
  import.meta.env.VITE_MARKETPLACE_PACKAGE_ID || "";

export const MARKETPLACE_LATEST_PACKAGE_ID =
  import.meta.env.VITE_MARKETPLACE_LATEST_PACKAGE_ID ||
  MARKETPLACE_PACKAGE_ID;

export const ESCROW_PACKAGE_ID =
  import.meta.env.VITE_ESCROW_PACKAGE_ID || "";

export const ESCROW_LATEST_PACKAGE_ID =
  import.meta.env.VITE_ESCROW_LATEST_PACKAGE_ID ||
  ESCROW_PACKAGE_ID;

export const CLOCK_ID = "0x6";

export const MODULE = "marketplace";