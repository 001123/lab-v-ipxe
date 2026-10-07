import { PHASE_DEVELOPMENT_SERVER } from "next/constants";
import type { NextConfig } from "next";

import os from "node:os";

// Backend (V/veb) port; keep in sync with internal/config/config.v (LAB_V_IPXE_PORT, default 4793).
const PROXY = `http://127.0.0.1:${process.env.LAB_V_IPXE_PORT || "4793"}`;
const PROXY_PATHS = ["/api/:path*", "/healthz", "/boot.ipxe", "/os/:path*", "/assets/:path*"];

function getLocalDevOrigins(): string[] {
  const origins = new Set<string>(["localhost", "127.0.0.1", "192.168.250.202"]);
  try {
    const interfaces = os.networkInterfaces();
    for (const name of Object.keys(interfaces)) {
      for (const net of interfaces[name] || []) {
        if (!net.internal && net.family === "IPv4") {
          origins.add(net.address);
        }
      }
    }
  } catch {
    // fallback if os.networkInterfaces fails
  }
  return Array.from(origins);
}

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
      allowedDevOrigins: getLocalDevOrigins(),
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
