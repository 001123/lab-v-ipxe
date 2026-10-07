import { PHASE_DEVELOPMENT_SERVER } from "next/constants";
import type { NextConfig } from "next";

const PROXY = "http://127.0.0.1:8080";
const PROXY_PATHS = ["/api/:path*", "/healthz", "/boot.ipxe", "/os/:path*", "/assets/:path*"];

const tailwindTurbopack: NextConfig = {
  turbopack: {
    rules: {
      "*.css": {
        loaders: ["@tailwindcss/turbopack"],
        as: "*.css",
      },
    },
  },
};

// `output: export` does not support rewrites; only the dev server needs the API proxy.
const nextConfig = (phase: string): NextConfig => {
  if (phase === PHASE_DEVELOPMENT_SERVER) {
    return {
      ...tailwindTurbopack,
      rewrites: async () =>
        PROXY_PATHS.map((source) => ({ source, destination: PROXY + source })),
    };
  }
  return {
    ...tailwindTurbopack,
    output: "export",
    trailingSlash: false,
    images: { unoptimized: true },
    reactStrictMode: true,
  };
};

export default nextConfig;
