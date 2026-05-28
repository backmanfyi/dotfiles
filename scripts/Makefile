# NvimOpen.app build and install
# Usage:
#   make          — build + install
#   make build    — compile app, set icon, patch plist, register with Launch Services
#   make install  — apply duti file associations
#   make clean    — remove ~/Applications/NvimOpen.app

SCRIPTS_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
OUTPUT      := $(HOME)/Applications/NvimOpen.app
APPLESCRIPT := $(SCRIPTS_DIR)NvimOpen.applescript
PLIST_SH    := $(SCRIPTS_DIR)nvim-open-plist.sh
NVIM_PNG    := /opt/homebrew/share/icons/hicolor/128x128/apps/nvim.png
DUTI_CONFIG := $(HOME)/.config/duti/nvim-open.duti
LSREG       := /System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister

.PHONY: all build install clean

all: build install

build:
	@echo "==> Compiling NvimOpen.app..."
	@mkdir -p $(HOME)/Applications
	osacompile -o "$(OUTPUT)" "$(APPLESCRIPT)"
	@if [ -f "$(NVIM_PNG)" ]; then \
		echo "==> Setting Neovim icon..."; \
		ICONSET=$$(mktemp -d)/nvim.iconset; \
		mkdir -p "$$ICONSET"; \
		sips -z 16  16  "$(NVIM_PNG)" --out "$$ICONSET/icon_16x16.png"      >/dev/null; \
		sips -z 32  32  "$(NVIM_PNG)" --out "$$ICONSET/icon_16x16@2x.png"   >/dev/null; \
		sips -z 32  32  "$(NVIM_PNG)" --out "$$ICONSET/icon_32x32.png"      >/dev/null; \
		sips -z 64  64  "$(NVIM_PNG)" --out "$$ICONSET/icon_32x32@2x.png"   >/dev/null; \
		sips -z 128 128 "$(NVIM_PNG)" --out "$$ICONSET/icon_128x128.png"    >/dev/null; \
		sips -z 256 256 "$(NVIM_PNG)" --out "$$ICONSET/icon_128x128@2x.png" >/dev/null; \
		iconutil -c icns "$$ICONSET" -o "$(OUTPUT)/Contents/Resources/nvim.icns"; \
		rm -rf "$$(dirname $$ICONSET)"; \
	else \
		echo "Warning: nvim.png not found at $(NVIM_PNG) — skipping icon" >&2; \
	fi
	@echo "==> Patching Info.plist..."
	bash "$(PLIST_SH)" "$(OUTPUT)"
	@echo "==> Registering with Launch Services..."
	"$(LSREG)" -f "$(OUTPUT)"
	@echo "==> NvimOpen.app built at $(OUTPUT)"

install:
	@if ! command -v duti >/dev/null 2>&1; then \
		echo "duti not found — run: brew install duti" >&2; exit 1; \
	fi
	@echo "==> Applying file associations via duti..."
	"$(LSREG)" -f "$(OUTPUT)"
	duti -v "$(DUTI_CONFIG)" 2>&1 | grep -v "dyn\." | grep -v "^$$" || true
	@echo "==> File associations applied"

clean:
	rm -rf "$(OUTPUT)"
	@echo "==> Removed $(OUTPUT)"
