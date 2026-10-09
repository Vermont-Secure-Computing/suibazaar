import { defineConfig, loadEnv } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), "");
  const network = env.VITE_SUI_NETWORK || "devnet";

  const RPC_URLS = {
    devnet: "https://fullnode.devnet.sui.io",
    mainnet: "https://fullnode.mainnet.sui.io",
  };

  if (!RPC_URLS[network]) {
    throw new Error(`Unsupported Sui network: ${network}`);
  }

  return {
    plugins: [react()],

    server: {
      proxy: {
        "/sui-rpc": {
          target: RPC_URLS[network],
          changeOrigin: true,
          secure: true,
          rewrite: (path) => path.replace(/^\/sui-rpc/, ""),
        },
      },
    },
  };
});
