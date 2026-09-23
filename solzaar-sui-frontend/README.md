# Solzaar Sui Frontend

Devnet test build reconstructed from the uploaded Solzaar frontend.

## Run

```bash
cp .env.example .env
npm install
npm run dev
```

Before transaction testing, set `VITE_MARKETPLACE_PACKAGE_ID` in `.env` to the FINAL deployed Solzaar package ID. Do not use a dry-run package ID.
