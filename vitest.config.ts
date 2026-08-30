import { defineConfig } from "vitest/config";
import path from "node:path";

// Separate from vite.config.ts on purpose: that file is wired through
// @lovable.dev/vite-tanstack-config (TanStack Start/Nitro/Cloudflare
// plugins), which Vitest doesn't need and which isn't safe to load outside
// a dev/build run. Tests only need plain TS + the `@` path alias.
export default defineConfig({
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "./src"),
    },
  },
  test: {
    // jsdom (not "node") because src/store/gameStore.ts's zustand `persist`
    // middleware touches `localStorage` at import time.
    environment: "jsdom",
    include: ["src/**/*.test.ts"],
  },
});
