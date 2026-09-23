import React from "react";
import ReactDOM from "react-dom/client";
import { BrowserRouter } from "react-router-dom";
import { DAppKitProvider } from "@mysten/dapp-kit-react";

import { dAppKit } from "./dapp-kit";

import "@mysten/dapp-kit-react/ui";
import "./index.css";
import "./App.css";

import App from "./App";

ReactDOM.createRoot(document.getElementById("root")).render(
  <React.StrictMode>
    <DAppKitProvider dAppKit={dAppKit}>
      <BrowserRouter>
        <App />
      </BrowserRouter>
    </DAppKitProvider>
  </React.StrictMode>
);
