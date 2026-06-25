#!/usr/bin/env bash
# Bridge a Claude Code hook event to fast-mempalace, pinning the global palace
# and embedding model so memory is consistent across every project. The hook
# JSON arrives on stdin and the response goes to stdout — we just pass through.
export FAST_MEMPALACE_DB="${FAST_MEMPALACE_DB:-$HOME/.fast-mempalace/palace.db}"
export FAST_MEMPALACE_MODEL="${FAST_MEMPALACE_MODEL:-$HOME/.fast-mempalace/lib/minilm.gguf}"
BIN="${FAST_MEMPALACE_BIN:-$HOME/.fast-mempalace/bin/fast-mempalace}"

# If the binary isn't installed, stay silent and let the session continue.
[ -x "$BIN" ] || { echo '{}'; exit 0; }
exec "$BIN" hook
