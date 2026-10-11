#!/usr/bin/env bash
# Runs every automated check: unit tests, runtime tests (map, client UI,
# server integration) and the Luau type checker against the Roblox API.
# Requires: lune, rojo, luau-lsp (+ Roblox type definitions file).
set -euo pipefail
cd "$(dirname "$0")"
DEFS="${ROBLOX_DEFS:-/tmp/globalTypes.d.luau}"
status=0
for spec in shared server map ui server_runtime; do
	echo "== tests/$spec.spec.luau"
	lune run "tests/$spec.spec.luau" | grep -v "^\[WARN\]\|^\[DataService\]\|^\[Monetization\]" || status=1
done
if command -v luau-lsp >/dev/null && [ -f "$DEFS" ]; then
	echo "== luau-lsp type check"
	rojo sourcemap default.project.json -o sourcemap.json >/dev/null
	out=$(luau-lsp analyze --definitions="$DEFS" --sourcemap=sourcemap.json src 2>&1 | grep -v "^\[" || true)
	if [ -n "$out" ]; then echo "$out"; status=1; else echo "no type errors"; fi
fi
exit $status
