<div align="center">
  <img src="assets/logo.svg" alt="Fast MemPalace Logo" width="350"/>
  <h1>fast-mempalace</h1>
  <p><b>200× faster, zero-dependency Zig rewrite of Python <code>mempalace</code>.</b></p>
</div>

---

Native, statically linked. Reads the same `mempalace.yaml`, same CLI surface. `ChromaDB` + `Pydantic` out; `sqlite-vec` + `llama.cpp` + `std.Io.Group` in.

## ⚡ Install

```bash
curl -fsSL https://raw.githubusercontent.com/MemPalace/fast-mempalace/main/install.sh | bash
```

Detects `darwin|linux` × `x86_64|aarch64`. Binary + GGUF land in `~/.fast-mempalace/`. No Python.

## 🎯 Drop-in replacement

```bash
pip uninstall mempalace
curl -fsSL https://raw.githubusercontent.com/MemPalace/fast-mempalace/main/install.sh | bash
```

Legacy scripts calling `mempalace`? Symlink:

```bash
ln -s ~/.fast-mempalace/bin/fast-mempalace ~/.fast-mempalace/bin/mempalace
```

## 🚀 Architecture

- **Zero deps** — single static binary.
- **Sub-ms retrieval** — `sqlite-vec`, `mmap_size=512MB`.
- **Bare-metal embeddings** — `llama.cpp` static; Metal / CUDA.
- **Concurrent mining** — `std.Io.Group`.
- **Local reranker** — `std.http.Client` → Ollama.

## 📊 Benchmarks

<div align="center">

**Apple M2 · cold runs**

| | 🐢 Python `mempalace` | ⚡ Zig `fast-mempalace` | Speedup | Less RAM |
|:--|:--:|:--:|:--:|:--:|
| **Cold start** <br/> `init` / `stats` | `1.40 s` <br/> `50 MB` | **`0.01 s`** <br/> **`8 MB`** | **140×** | **6×** |
| **Mine** <br/> 450 KB · 1 171 drawers | `~120 s` <br/> `320 MB` | **`0.59 s`** <br/> **`95 MB`** | **203×** | **3.4×** |
| **Search** <br/> semantic query | `0.78 s` <br/> `270 MB` | **`0.59 s`** <br/> **`94 MB`** | `1.3×` | **2.9×** |
| **Wake-up / kg** <br/> context load | `0.53 s` <br/> `76 MB` | **`0.02 s`** <br/> **`8 MB`** | **26×** | **9×** |

</div>

### Relative timing (lower = faster)

```text
Cold start     🐢 ████████████████████ 1.40 s
                ⚡ ▏                    0.01 s

Mine           🐢 ████████████████████ 120 s
                ⚡ ▏                    0.59 s

Search         🐢 ████████████████████ 0.78 s
                ⚡ ███████████████      0.59 s

Wake-up / kg   🐢 ████████████████████ 0.53 s
                ⚡ ▏                    0.02 s
```

Corpus: [OmniVoice-Studio](https://github.com/debpalash/OmniVoice-Studio). Methodology → [`BENCHMARK.md`](./BENCHMARK.md).

## 📦 Commands

```text
fast-mempalace init                  Initialize palace database
fast-mempalace mine <path> [wing]    Mine files into the palace
fast-mempalace search <query>        Semantic search
fast-mempalace stats                 Palace statistics
fast-mempalace kg [subject]          Query knowledge graph
fast-mempalace wake-up [--wing X]    Show L0+L1 wake-up context
fast-mempalace hook                  Run hook (JSON stdin/stdout)
fast-mempalace instructions          Output skill instructions
fast-mempalace mcp                   Start MCP JSON-RPC server
```

## 🐳 Local CI (Docker)

Mirror the Ubuntu GitHub Actions leg locally before pushing:

```bash
./scripts/ci-local.sh
```

Requires Docker daemon. Builds `Dockerfile.ci` → runs smoke test.

## 🔧 Build from source

Needs `zig 0.16.0` + `cmake`.

```bash
git clone --recursive https://github.com/MemPalace/fast-mempalace
cd fast-mempalace
mkdir -p lib && curl -L -o lib/minilm.gguf \
  "https://huggingface.co/nomic-ai/nomic-embed-text-v1.5-GGUF/resolve/main/nomic-embed-text-v1.5.f16.gguf"
zig build --release=fast
./zig-out/bin/fast-mempalace stats
```

## ⚙️ Configuration

Reads `fast-mempalace.yaml`, falls back to `mempalace.yaml` for drop-in compat.

```yaml
database_path: "fast-mempalace.db"
model_path: "lib/minilm.gguf"
default_wing: "production"
ignore_patterns:
  - ".git"
  - ".zig-cache"
```

## 🗺️ Roadmap

Parity + outmatch milestones → [`ROADMAP.md`](./ROADMAP.md).

## 📄 License

[MIT](./LICENSE).
