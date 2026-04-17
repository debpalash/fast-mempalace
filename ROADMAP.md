# 🗺️ Roadmap — Parity & Outmatch

Path from `fast-mempalace` today to **full drop-in parity** with the upstream Python `mempalace` package, then to **outmatching** it with capabilities the Python stack cannot reach.

Legend: `[x]` done · `[~]` partial · `[ ]` planned

---

## Phase 0 — Shipped (v0.1)

Core engine that runs the four pillars faster than upstream while holding 80–93% less RAM (see `BENCHMARK.md`).

- [x] `init` / `stats` — palace DB bootstrap + pragma mapping
- [x] `mine <path> [wing]` — concurrent file ingestion (single-file path; directory walker being fixed in v0.1.1)
- [x] `search <query>` — sqlite-vec L2 semantic retrieval
- [x] `kg [subject]` — knowledge-graph relationship query
- [x] `wake-up [--wing X]` — L0+L1 context loader (~600–900 tok)
- [x] `hook` — JSON stdin/stdout for Claude Code hook pipeline
- [x] `instructions` — skill-instruction emitter
- [x] `mcp` — JSON-RPC MCP server for editor integration
- [x] `mempalace.yaml` + `fast-mempalace.yaml` drop-in config
- [x] Native Metal / CUDA embedding via statically linked `llama.cpp`
- [x] MIT license, GitHub Actions CI, one-line curl installer, prebuilt release binaries
- [x] OmniVoice corpus benchmark (450 KB → 1 171 drawers in 0.59 s)

---

## Phase 1 — Full Parity (v0.2)

Close every remaining gap with the upstream `pip install mempalace` surface. Each item blocks the "100% drop-in" claim.

> ⚠ Upstream CLI audit is still pending (PyPI fetch was blocked during planning). These items are inferred from project structure and the typical memory-tool surface. Cross-check against the upstream docs before cutting v0.2.

- [ ] **Directory walker bug** — `fast-mempalace mine <dir>` currently enumerates 0 files; single-file path works. Root cause in `src/miner.zig` walker loop on Zig 0.16. Blocks large-repo mining.
- [ ] **`mine` flag parity** — `--wing`, `--room`, `--recursive`, `--ignore`, `--dry-run`
- [ ] **`search` flag parity** — `--limit`, `--wing`, `--format=json|md|plain`, similarity threshold
- [ ] **`init` vs `stats`** — upstream uses `init`; alias our `stats` where appropriate
- [ ] **Incremental re-mining** — content-hash skip for unchanged files (currently re-embeds all)
- [ ] **`forget <id|wing>`** — evict drawers
- [ ] **Export / import** — `fast-mempalace export <path>` JSONL dump + re-ingest round-trip
- [ ] **Ignore-pattern parity** — `.gitignore`-style globs matching upstream semantics
- [ ] **Config schema audit** — every upstream yaml key respected or rejected with a diagnostic
- [ ] **Python-parity output strings** — exit codes, stderr format, progress-bar layout for script consumers
- [ ] **Embedding model swap** — allow upstream's default model name via `model: <name>` resolving to HF URL

**Definition of done:** a user can `pip uninstall mempalace && curl ... | bash && ln -s .../fast-mempalace .../mempalace` and every script in their pipeline keeps working unchanged.

---

## Phase 2 — Outmatch (v0.3–v0.5)

Ship features upstream Python cannot match without rewriting. Each lands a capability bullet on the README.

### v0.3 — Performance Frontier

- [ ] **Batched embedding kernel** — vectorize mine across N files per GPU call (target: 10× mine throughput vs current 200×)
- [ ] **Incremental vector index** — sqlite-vec HNSW params tuned per drawer-count bucket
- [ ] **Zero-copy mmap ingest** — large file mining without full read-into-RAM
- [ ] **Compile-time schema** — Zig comptime validation of `fast-mempalace.yaml`; bad config fails at build, not runtime

### v0.4 — Reach Beyond CLI

- [ ] **Watch mode** — `fast-mempalace watch <path>` file-system events → auto re-mine (upstream Python blocks on ChromaDB lock; we don't)
- [ ] **Embedded HTTP API** — `fast-mempalace serve --port 8080` pure Zig handler, <5 MB RAM overhead
- [ ] **Web UI** — single-file static dashboard shipped inside binary (SQLite browser + search box)
- [ ] **Hybrid search** — BM25 + vector fusion (upstream is vector-only)
- [ ] **Time-scoped queries** — `--since 2026-01-01`, `--until`, decay-weighted ranking

### v0.5 — Ecosystem & Distribution

- [ ] **Homebrew formula** — `brew install fast-mempalace`
- [ ] **Docker image** — ~15 MB distroless image (vs upstream ~1.2 GB Python+ML)
- [ ] **Shell completions** — zsh / bash / fish
- [ ] **Claude Code plugin** — one-line install that wires hooks + MCP + slash commands
- [ ] **Plugin SDK** — stable `lib/fast_mempalace.h` C ABI for 3rd-party languages

### v0.6+ — Intelligence Layer

- [ ] **Auto-consolidation** — dream-cycle re-embedding to compact similar drawers
- [ ] **Knowledge-graph extraction** — NER on mine to auto-populate entity edges (currently manual)
- [ ] **Multi-modal** — image / PDF mining via local vision GGUFs
- [ ] **Federated palaces** — optional peer-to-peer sync between machines (E2E-encrypted)

---

## Non-goals

- Cloud SaaS or managed hosting
- Python-binding wrapper (keep the stack Zig-native; use the binary)
- ChromaDB / Pinecone / Weaviate compatibility shims
- Any feature that requires a network call at query time

---

## Contributing

Open an issue with the `roadmap` label. Phase 1 items that unblock the parity claim get priority over Phase 2+. Benchmark every perf claim against `BENCHMARK.md` methodology before merging.
