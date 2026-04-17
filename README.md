<div align="center">
  <img src="assets/logo.svg" alt="Fast MemPalace Logo" width="350"/>
  <h1>fast-mempalace</h1>
  <p><b>The 200× faster, zero-dependency Zig rewrite of the Python <code>mempalace</code> package.</b></p>
</div>

---

`fast-mempalace` is a native, statically linked rewrite of the legacy Python [`mempalace`](https://pypi.org/project/mempalace/) package. It reads the same `mempalace.yaml`, exposes the same command surface, and collapses extraction times from **minutes to milliseconds** by replacing `ChromaDB` + `Pydantic` + Python I/O with `sqlite-vec` + `llama.cpp` + `std.Io.Group`.

## ⚡ Install in one line

```bash
curl -fsSL https://raw.githubusercontent.com/MemPalace/fast-mempalace/main/install.sh | bash
```

Detects your platform (`darwin|linux` × `x86_64|aarch64`), downloads the prebuilt native binary from the latest GitHub Release, and stores the embedding model in `~/.fast-mempalace/`. No Python, no virtualenv, no package manager.

## 🎯 Drop-in replacement

`fast-mempalace` reads the same `mempalace.yaml` config your Python scripts already use. Migrate in two lines:

```bash
pip uninstall mempalace
curl -fsSL https://raw.githubusercontent.com/MemPalace/fast-mempalace/main/install.sh | bash
```

Optional — alias the binary so legacy scripts calling `mempalace` keep working:

```bash
ln -s ~/.fast-mempalace/bin/fast-mempalace ~/.fast-mempalace/bin/mempalace
```

## 🚀 Architecture

- **Zero-dependency core** — single static binary, `zig build` only.
- **Sub-millisecond retrieval** — `sqlite-vec` memory-mapped at `PRAGMA mmap_size=512MB`.
- **Bare-metal embeddings** — `llama.cpp` linked statically; Apple Silicon (Metal) or CUDA.
- **Concurrent mining** — Zig `std.Io.Group` parallelism across file processing.
- **Local LLM reranker** — `std.http.Client` against Ollama / any local endpoint.

## 📊 Benchmarks

<div align="center">

**Apple M2 · macOS · cold runs · identical workloads**

| | 🐢 Python `mempalace` | ⚡ Zig `fast-mempalace` | Speedup | Less RAM |
|:--|:--:|:--:|:--:|:--:|
| **Cold start** <br/> `init` / `stats` | `1.40 s` <br/> `50 MB` | **`0.01 s`** <br/> **`8 MB`** | **140×** | **6×** |
| **Mine** <br/> 450 KB · 1 171 drawers | `~120 s` <br/> `320 MB` | **`0.59 s`** <br/> **`95 MB`** | **203×** | **3.4×** |
| **Search** <br/> semantic query | `0.78 s` <br/> `270 MB` | **`0.59 s`** <br/> **`94 MB`** | `1.3×` | **2.9×** |
| **Wake-up / kg** <br/> context load | `0.53 s` <br/> `76 MB` | **`0.02 s`** <br/> **`8 MB`** | **26×** | **9×** |

</div>

### Relative timing (lower = faster)

```
Cold start     🐢 ████████████████████ 1.40 s
                ⚡ ▏                    0.01 s

Mine           🐢 ████████████████████ 120 s
                ⚡ ▏                    0.59 s

Search         🐢 ████████████████████ 0.78 s
                ⚡ ███████████████      0.59 s

Wake-up / kg   🐢 ████████████████████ 0.53 s
                ⚡ ▏                    0.02 s
```

Mining corpus: [OmniVoice-Studio](https://github.com/debpalash/OmniVoice-Studio) — cinematic audio dubbing, cloning, and voice generation studio. Full methodology, reproduction steps, and extended commands in [`BENCHMARK.md`](./BENCHMARK.md).

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

## 🔧 Build from source

Requires `zig 0.16.0` and `cmake`.

```bash
git clone --recursive https://github.com/MemPalace/fast-mempalace
cd fast-mempalace
mkdir -p lib && curl -L -o lib/minilm.gguf \
  "https://huggingface.co/nomic-ai/nomic-embed-text-v1.5-GGUF/resolve/main/nomic-embed-text-v1.5.f16.gguf"
zig build --release=fast
./zig-out/bin/fast-mempalace stats
```

## ⚙️ Configuration (`fast-mempalace.yaml` or `mempalace.yaml`)

Drop-in compatible with the Python package. The binary searches for `fast-mempalace.yaml` first, then falls back to `mempalace.yaml`.

```yaml
database_path: "fast-mempalace.db"
model_path: "lib/minilm.gguf"
default_wing: "production"
ignore_patterns:
  - ".git"
  - ".zig-cache"
```

## 🗺️ Roadmap

Parity + outmatch milestones in [`ROADMAP.md`](./ROADMAP.md).

## 📄 License

[MIT](./LICENSE) — ship it, fork it, vendor it.
