import { createDAppKit } from "@mysten/dapp-kit-react";
import { SuiGrpcClient } from "@mysten/sui/grpc";

const NETWORK = import.meta.env.VITE_SUI_NETWORK || "devnet";

const GRPC_URLS = {
  devnet: "https://fullnode.devnet.sui.io:443",
  testnet: "https://fullnode.testnet.sui.io:443",
  mainnet: "https://fullnode.mainnet.sui.io:443",
};

if (!GRPC_URLS[NETWORK]) {
  throw new Error(`Unsupported Sui network: ${NETWORK}`);
}

export const dAppKit = createDAppKit({
  networks: [NETWORK],
  defaultNetwork: NETWORK,
  autoConnect: true,

  createClient(network) {
    return new SuiGrpcClient({
      network,
      baseUrl: GRPC_URLS[network],
    });
  },
});
