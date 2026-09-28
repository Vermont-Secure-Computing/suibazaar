import { useState } from "react";
import { createPortal } from "react-dom";

import {
  useCurrentAccount,
  useCurrentWallet,
  useDAppKit,
  useWallets,
} from "@mysten/dapp-kit-react";

const WALLET_CATALOG = [
  {
    id: "slush",
    name: "Slush",
    aliases: ["slush", "sui wallet"],
    installUrl: "https://slush.app/",
  },
  {
    id: "suiet",
    name: "Suiet",
    aliases: ["suiet"],
    installUrl: "https://suiet.app/",
  },
  {
    id: "surf",
    name: "Surf Wallet",
    aliases: ["surf", "surf wallet"],
    installUrl: "https://surf.tech/",
  },
  {
    id: "nightly",
    name: "Nightly",
    aliases: ["nightly", "nightly wallet"],
    installUrl: "https://nightly.app/",
  },
  {
    id: "okx",
    name: "OKX Wallet",
    aliases: ["okx", "okx wallet"],
    installUrl: "https://web3.okx.com/download",
  },
  {
    id: "bitget",
    name: "Bitget Wallet",
    aliases: ["bitget", "bitget wallet"],
    installUrl: "https://web3.bitget.com/",
  },
];

function normalizeName(name = "") {
  return name.toLowerCase().trim();
}

function findDetectedWallet(catalogWallet, detectedWallets) {
  return detectedWallets.find((wallet) => {
    const detectedName = normalizeName(wallet.name);

    return catalogWallet.aliases.some((alias) => {
      const normalizedAlias = normalizeName(alias);

      return (
        detectedName === normalizedAlias ||
        detectedName.includes(normalizedAlias)
      );
    });
  });
}

function shortAddress(address) {
  if (!address) return "";

  return `${address.slice(0, 6)}...${address.slice(-4)}`;
}

export default function WalletButton() {
  const dAppKit = useDAppKit();
  const wallets = useWallets();
  const account = useCurrentAccount();
  const currentWallet = useCurrentWallet();

  const [showModal, setShowModal] = useState(false);
  const [showAccountMenu, setShowAccountMenu] = useState(false);
  const [connecting, setConnecting] = useState(null);
  const [error, setError] = useState("");
  const [copied, setCopied] = useState(false);

  const connectWallet = async (wallet) => {
    try {
      setError("");
      setConnecting(wallet.name);

      await dAppKit.connectWallet({
        wallet,
      });

      setShowModal(false);
    } catch (err) {
      console.error("Wallet connection failed:", err);

      setError(
        err?.message ||
          "Unable to connect wallet. Please try again."
      );
    } finally {
      setConnecting(null);
    }
  };

  const disconnectWallet = async () => {
    try {
      await dAppKit.disconnectWallet();
      setShowAccountMenu(false);
    } catch (err) {
      console.error("Wallet disconnect failed:", err);
    }
  };

  const copyAddress = async () => {
    if (!account?.address) return;

    try {
      await navigator.clipboard.writeText(account.address);

      setCopied(true);

      setTimeout(() => {
        setCopied(false);
      }, 1500);
    } catch (err) {
      console.error("Unable to copy address:", err);
    }
  };

  const installWallet = (url) => {
    window.open(
      url,
      "_blank",
      "noopener,noreferrer"
    );
  };

  const catalogWallets = WALLET_CATALOG.map(
    (catalogWallet) => ({
      ...catalogWallet,

      detectedWallet: findDetectedWallet(
        catalogWallet,
        wallets
      ),
    })
  );

  const extraDetectedWallets = wallets.filter(
    (wallet) => {
      return !WALLET_CATALOG.some(
        (catalogWallet) =>
          findDetectedWallet(
            catalogWallet,
            [wallet]
          )
      );
    }
  );

  /*
   * CONNECTED
   */
  if (account) {
    return (
      <div className="custom-wallet-wrapper">
        <button
          type="button"
          className="custom-wallet-button"
          onClick={() =>
            setShowAccountMenu(!showAccountMenu)
          }
        >
          {currentWallet?.icon && (
            <img
              src={currentWallet.icon}
              alt=""
              className="custom-wallet-small-icon"
            />
          )}

          <span>
            {shortAddress(account.address)}
          </span>

          <span className="custom-wallet-arrow">
            ▾
          </span>
        </button>

        {showAccountMenu &&
          createPortal(
            <>
              <div
                className="wallet-menu-backdrop"
                onClick={() =>
                  setShowAccountMenu(false)
                }
              />

              <div className="custom-account-menu">
                <div className="custom-account-header">
                  <div className="custom-account-wallet">
                    {currentWallet?.icon && (
                      <img
                        src={currentWallet.icon}
                        alt=""
                        className="custom-account-icon"
                      />
                    )}

                    <div>
                      <strong>
                        {currentWallet?.name ||
                          "Sui Wallet"}
                      </strong>

                      <small>Sui Devnet</small>
                    </div>
                  </div>

                  <div className="custom-account-address">
                    {shortAddress(
                      account.address
                    )}
                  </div>
                </div>

                <button
                  type="button"
                  className="custom-account-action"
                  onClick={copyAddress}
                >
                  {copied
                    ? "✓ Address copied"
                    : "Copy address"}
                </button>

                <button
                  type="button"
                  className="custom-account-action custom-disconnect"
                  onClick={disconnectWallet}
                >
                  Disconnect
                </button>
              </div>
            </>,
            document.body
          )}
      </div>
    );
  }

  /*
   * DISCONNECTED
   */
  return (
    <>
      <button
        type="button"
        className="custom-wallet-button"
        onClick={() => {
          setError("");
          setShowModal(true);
        }}
      >
        Connect Wallet
      </button>

      {showModal &&
        createPortal(
          <div
            className="wallet-modal-overlay"
            onClick={() =>
              setShowModal(false)
            }
          >
            <div
              className="wallet-modal-box"
              onClick={(event) =>
                event.stopPropagation()
              }
            >
              <div className="wallet-modal-header">
                <div>
                  <h2>Connect Wallet</h2>

                  <p>
                    Choose a wallet to connect
                    to Solzaar
                  </p>
                </div>

                <button
                  type="button"
                  className="wallet-modal-close"
                  onClick={() =>
                    setShowModal(false)
                  }
                >
                  ×
                </button>
              </div>

              <div className="wallet-modal-list">
                {catalogWallets.map(
                  (wallet) => {
                    const detected =
                      wallet.detectedWallet;

                    const isConnecting =
                      connecting ===
                      detected?.name;

                    return (
                      <button
                        key={wallet.id}
                        type="button"
                        className="wallet-modal-item"
                        disabled={
                          connecting !==
                            null &&
                          !isConnecting
                        }
                        onClick={() => {
                          if (detected) {
                            connectWallet(
                              detected
                            );
                          } else {
                            installWallet(
                              wallet.installUrl
                            );
                          }
                        }}
                      >
                        <div className="wallet-modal-info">
                          {detected?.icon ? (
                            <img
                              src={
                                detected.icon
                              }
                              alt=""
                              className="wallet-modal-icon"
                            />
                          ) : (
                            <div className="wallet-modal-placeholder">
                              {wallet.name
                                .charAt(0)
                                .toUpperCase()}
                            </div>
                          )}

                          <div>
                            <strong>
                              {wallet.name}
                            </strong>

                            <small>
                              {detected
                                ? "Installed"
                                : "Not installed"}
                            </small>
                          </div>
                        </div>

                        <span
                          className={
                            detected
                              ? "wallet-connect-action"
                              : "wallet-install-action"
                          }
                        >
                          {isConnecting
                            ? "Connecting..."
                            : detected
                              ? "Connect"
                              : "Install ↗"}
                        </span>
                      </button>
                    );
                  }
                )}

                {extraDetectedWallets.length >
                  0 && (
                  <>
                    <div className="wallet-list-divider" />

                    <div className="wallet-other-title">
                      Other detected wallets
                    </div>

                    {extraDetectedWallets.map(
                      (wallet) => (
                        <button
                          key={wallet.name}
                          type="button"
                          className="wallet-modal-item"
                          disabled={
                            connecting !==
                            null
                          }
                          onClick={() =>
                            connectWallet(
                              wallet
                            )
                          }
                        >
                          <div className="wallet-modal-info">
                            {wallet.icon ? (
                              <img
                                src={
                                  wallet.icon
                                }
                                alt=""
                                className="wallet-modal-icon"
                              />
                            ) : (
                              <div className="wallet-modal-placeholder">
                                {wallet.name
                                  .charAt(0)
                                  .toUpperCase()}
                              </div>
                            )}

                            <div>
                              <strong>
                                {wallet.name}
                              </strong>

                              <small>
                                Installed
                              </small>
                            </div>
                          </div>

                          <span className="wallet-connect-action">
                            {connecting ===
                            wallet.name
                              ? "Connecting..."
                              : "Connect"}
                          </span>
                        </button>
                      )
                    )}
                  </>
                )}

                {error && (
                  <div className="wallet-modal-error">
                    {error}
                  </div>
                )}
              </div>

              <div className="wallet-modal-footer">
                Never share your recovery
                phrase with Solzaar or any
                website.
              </div>
            </div>
          </div>,
          document.body
        )}
    </>
  );
}