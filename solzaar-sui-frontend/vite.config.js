import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig({
  plugins: [react()],

  server: {
    proxy: {
      "/sui-rpc": {
        target: "https://fullnode.devnet.sui.io",
        changeOrigin: true,
        secure: true,
        rewrite: (path) => path.replace(/^\/sui-rpc/, ""),
      },
    },
  },
});