# github-openwrt — Cross-compiled GitHub CLI for OpenWrt

Cross-compiles `gh` (GitHub CLI) as a statically-linked binary for OpenWrt routers running musl libc on aarch64.

## Target

| Property | Value |
|---|---|
| **Router OS** | OpenWrt SNAPSHOT (mediatek/filogic) |
| **Architecture** | `aarch64_cortex-a53` |
| **libc** | musl |
| **Go target** | `GOOS=linux GOARCH=arm64 CGO_ENABLED=0` |

## Prerequisites

- Go 1.26+ installed on the build host
- GitHub CLI source checkout at `../github/cli` (relative to this project)
- `sshpass` for automated router deployment
- `upx` (optional) for binary compression

## Build

```bash
make build
```

This cross-compiles `gh` and outputs the binary to `bin/gh-openwrt-arm64`.

## Deploy

```bash
make deploy
```

This copies the binary to the router at `/mnt/appdata/bin/gh`, creates a symlink at `/usr/bin/gh`, and bootstraps authentication from the existing orchestrator config.

## Manual Auth Setup

If you prefer manual auth on the router:
```bash
ssh root@10.0.0.1
echo "YOUR_GITHUB_PAT" | /mnt/appdata/bin/gh auth login --with-token
gh auth status
```

## Automated Builds (CI)

A GitHub Actions workflow checks for new [cli/cli](https://github.com/cli/cli) releases every 6 hours. When a new version is detected:

1. Clones the upstream tag
2. Cross-compiles for `linux/arm64` with `CGO_ENABLED=0` (static, stripped)
3. Compresses with UPX
4. Publishes a GitHub Release with the binary and checksums

You can also trigger a build manually from the **Actions** tab with an optional force-rebuild flag.

### Install from Release

```bash
# On the router
wget -O /mnt/appdata/bin/gh https://github.com/RPDevs-Vault/github-openwrt/releases/latest/download/gh-openwrt-arm64-uncompressed
chmod +x /mnt/appdata/bin/gh
ln -sf /mnt/appdata/bin/gh /usr/bin/gh
```

## Integration with github-orchestrator

With `gh` available on the router, the orchestrator can optionally use `gh api` instead of raw `curl` calls for:
- Automatic token management (no need to pass `-H "Authorization: token ..."`)
- Built-in pagination for large result sets
- Richer error handling and retry logic

