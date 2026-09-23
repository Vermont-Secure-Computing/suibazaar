import { createDAppKit } from "@mysten/dapp-kit-react";
import { SuiGrpcClient } from "@mysten/sui/grpc";

const GRPC_URLS = {
  devnet: "https://fullnode.devnet.sui.io:443",
};

export const dAppKit = createDAppKit({
  networks: ["devnet"],
  defaultNetwork: "devnet",
  autoConnect: true,

  createClient(network) {
    return new SuiGrpcClient({
      network,
      baseUrl: GRPC_URLS[network],
    });
  },
});
