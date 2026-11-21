import { defineConfig } from "astro/config";

// No GitHub Actions, SITE_URL e SITE_BASE vem do actions/configure-pages
// (ex.: https://usuario.github.io e /leitoaberto). Localmente o site roda na raiz.
export default defineConfig({
  site: process.env.SITE_URL || "http://localhost:4321",
  base: process.env.SITE_BASE || "/",
  trailingSlash: "ignore",
  build: { format: "directory" },
});
