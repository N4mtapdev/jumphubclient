#!/bin/sh
# Jump Hub — rebuild main.lua from JumpHubClient.lua.
#
# Self-contained: downloads a pinned Prometheus release into a cache outside
# the repo, installs the repo's chemical name generator where Prometheus loads
# it from (src/prometheus/namegenerators/), then runs the Minify pipeline with
# the Luau target. No temp-dir dependency; everything regenerates from this repo.
#
# Usage:
#   sh tools/build.sh            # writes ./main.lua
#   sh tools/build.sh out.lua    # writes out.lua instead
#
# Requirements: sh, curl, tar, lua5.1 (package "lua5.1").
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
OUT=${1:-"$ROOT/main.lua"}
CACHE=${JUMPHUB_BUILD_CACHE:-"$HOME/.cache/jumphub-build"}
PROM="$CACHE/Prometheus"
URL="https://github.com/prometheus-lua/Prometheus/archive/refs/tags/v0.2.11.1.tar.gz"

if ! command -v lua5.1 >/dev/null 2>&1; then
	echo "build: lua5.1 not found (install the lua5.1 package)" >&2
	exit 1
fi

if [ ! -f "$PROM/src/cli.lua" ]; then
	echo "build: fetching Prometheus v0.2.11.1 -> $CACHE"
	mkdir -p "$CACHE"
	rm -rf "$CACHE/Prometheus" "$CACHE"/Prometheus-* "$CACHE/prom.tar.gz"
	curl -fsSL "$URL" -o "$CACHE/prom.tar.gz"
	tar -xzf "$CACHE/prom.tar.gz" -C "$CACHE"
	set -- "$CACHE"/Prometheus*
	if [ ! -d "${1:-}" ]; then
		echo "build: unexpected archive layout" >&2
		exit 1
	fi
	mv "$1" "$PROM"
	rm -f "$CACHE/prom.tar.gz"
fi

# Install the repo's chemical name generator at the path Prometheus requires
# (it does require("prometheus.namegenerators.chemical")), then register it.
# Both steps are idempotent so repeated builds are safe.
cp "$ROOT/tools/chemical.lua" "$PROM/src/prometheus/namegenerators/chemical.lua"
REG="$PROM/src/prometheus/namegenerators.lua"
if ! grep -q 'namegenerators.chemical' "$REG"; then
	printf '%s\n' \
		'return {' \
		'	Mangled = require("prometheus.namegenerators.mangled");' \
		'	MangledShuffled = require("prometheus.namegenerators.mangled_shuffled");' \
		'	Il = require("prometheus.namegenerators.Il");' \
		'	Number = require("prometheus.namegenerators.number");' \
		'	Confuse = require("prometheus.namegenerators.confuse");' \
		'	Chemical = require("prometheus.namegenerators.chemical");' \
		'}' > "$REG"
fi

echo "build: Minify + Chemical names + Luau target -> $OUT"
lua5.1 "$PROM/src/cli.lua" --LuaU \
	--config "$ROOT/prometheus.config.lua" \
	--out "$OUT" \
	"$ROOT/JumpHubClient.lua"
echo "build: done ($(wc -c < "$OUT") bytes)"
