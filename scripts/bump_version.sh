#!/usr/bin/env bash
# Updates version across web/package.json, web/package-lock.json, v.mod, and internal/config/config.v
# Usage: scripts/bump_version.sh <version>
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${ROOT}"

RAW_VERSION="${1:-}"
if [ -z "${RAW_VERSION}" ]; then
  echo "Usage: $0 <version> (e.g. 0.2.0 or v0.2.0)" >&2
  exit 1
fi

VERSION="${RAW_VERSION#v}"

echo "==> Bumping version to ${VERSION} across project files..."

# 1. Update web/package.json and web/package-lock.json
if [ -d "web" ]; then
  echo "--> Updating web/package.json and web/package-lock.json"
  (cd web && npm version "${VERSION}" --no-git-tag-version --allow-same-version)
fi

# 2. Update docs/package.json and docs/package-lock.json
if [ -d "docs" ] && [ -f "docs/package.json" ]; then
  echo "--> Updating docs/package.json and docs/package-lock.json"
  (cd docs && npm version "${VERSION}" --no-git-tag-version --allow-same-version)
fi

# 3. Update README.md version badge
if [ -f "README.md" ]; then
  echo "--> Updating README.md version badge"
  sed -i.bak -E "s/version-[0-9]+\.[0-9]+\.[0-9]+/version-${VERSION}/" README.md && rm -f README.md.bak
fi

# 4. Update v.mod
if [ -f "v.mod" ]; then
  echo "--> Updating v.mod"
  sed -i.bak -E "s/version: '[^']+'/version: '${VERSION}'/" v.mod && rm -f v.mod.bak
fi

# 5. Update internal/config/config.v
if [ -f "internal/config/config.v" ]; then
  echo "--> Updating internal/config/config.v"
  sed -i.bak -E "s/^pub const version = '[^']+'/pub const version = '${VERSION}'/" internal/config/config.v && rm -f internal/config/config.v.bak
fi

echo "==> Successfully bumped version to ${VERSION}"
