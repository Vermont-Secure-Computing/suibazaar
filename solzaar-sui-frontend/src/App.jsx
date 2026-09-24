import { Routes, Route, Link } from "react-router-dom";
import { ConnectButton } from "@mysten/dapp-kit-react/ui";

import Home from "./pages/Home";
import CreateMerchant from "./pages/CreateMerchant";
import CreateProduct from "./pages/CreateProduct";
import MerchantPage from "./pages/MerchantPage";
import ProductPage from "./pages/ProductPage";
import OrdersPage from "./pages/OrdersPage";
import OrderDetailsPage from "./pages/OrderDetailsPage";

export default function App() {
  return (
    <>
      <header className="app-header">
        <Link className="brand" to="/">
          Solzaar
        </Link>

        <nav>
          <Link to="/">Marketplace</Link>
          <Link to="/orders">Orders</Link>
          <Link to="/merchant/create">Create Merchant</Link>
          <Link to="/product/create">Create Product</Link>
        </nav>

        <div className="wallet">
          <span>Sui Devnet</span>
          <ConnectButton />
        </div>
      </header>

      <Routes>
        <Route path="/" element={<Home />} />
        <Route path="/merchant/create" element={<CreateMerchant />} />
        <Route path="/product/create" element={<CreateProduct />} />
        <Route path="/merchant/:id" element={<MerchantPage />} />
        <Route path="/product/:id" element={<ProductPage />} />
        <Route path="/orders" element={<OrdersPage />} />
        <Route
          path="/orders/:role/:escrowAddress"
          element={<OrderDetailsPage />}
        />
      </Routes>
    </>
  );
}
