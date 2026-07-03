.PHONY: build deploy clean compress

# Paths
CLI_SRC     := $(realpath ../github/cli)
GO          := /usr/local/go/bin/go
BINARY      := bin/gh-openwrt-arm64
VERSION     := $(shell git -C $(CLI_SRC) describe --tags --abbrev=0 2>/dev/null | sed 's/^v//')
BUILD_DATE  := $(shell date +%Y-%m-%d)

# Router
ROUTER_HOST := root@10.0.0.1
ROUTER_PASS := c1rd1sc1rd1s
ROUTER_BIN  := /mnt/appdata/bin/gh

# Cross-compile flags
export GOOS      := linux
export GOARCH    := arm64
export CGO_ENABLED := 0

LDFLAGS := -s -w \
  -X github.com/cli/cli/v2/internal/build.Version=$(VERSION) \
  -X github.com/cli/cli/v2/internal/build.Date=$(BUILD_DATE)

build:
	@echo "==> Cross-compiling gh $(VERSION) for linux/arm64 (static, stripped)..."
	cd $(CLI_SRC) && $(GO) build -trimpath -ldflags '$(LDFLAGS)' -o $(CURDIR)/$(BINARY) ./cmd/gh
	@echo "==> Build complete: $(BINARY)"
	@ls -lh $(BINARY)
	@file $(BINARY)

compress: build
	@if command -v upx >/dev/null 2>&1; then \
		echo "==> Compressing with upx..."; \
		upx --best --lzma $(BINARY); \
		ls -lh $(BINARY); \
	else \
		echo "==> upx not found, skipping compression"; \
	fi

deploy: build
	@echo "==> Deploying to router $(ROUTER_HOST)..."
	sshpass -p '$(ROUTER_PASS)' ssh -o StrictHostKeyChecking=no $(ROUTER_HOST) "mkdir -p /mnt/appdata/bin"
	sshpass -p '$(ROUTER_PASS)' scp -o StrictHostKeyChecking=no $(BINARY) $(ROUTER_HOST):$(ROUTER_BIN)
	sshpass -p '$(ROUTER_PASS)' ssh -o StrictHostKeyChecking=no $(ROUTER_HOST) "chmod +x $(ROUTER_BIN) && ln -sf $(ROUTER_BIN) /usr/bin/gh"
	@echo "==> Verifying on router..."
	sshpass -p '$(ROUTER_PASS)' ssh -o StrictHostKeyChecking=no $(ROUTER_HOST) "gh --version"
	@echo "==> Bootstrapping auth from orchestrator config..."
	sshpass -p '$(ROUTER_PASS)' ssh -o StrictHostKeyChecking=no $(ROUTER_HOST) \
		'TOKEN=$$(jq -r ".monitors[0].github_token" /etc/runner_orchestrator/config.json) && echo "$$TOKEN" | gh auth login --with-token && gh auth status'
	@echo "==> Done!"

clean:
	rm -rf bin/
