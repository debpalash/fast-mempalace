# ⏱️ fast-mempalace Benchmarks

Hardware performance of identical pipelines: legacy Pip `mempalace` (Python / ONNX / ChromaDB) vs `fast-mempalace` (Zig 0.16.0 / Metal / sqlite-vec).

Hardware: Apple M2, 16 GB, macOS. Each command run cold (fresh DB, fresh process). Memory = peak resident set size.

## 1. Cold start

Python carries ~1 s of `chromadb` + `pydantic` parse overhead before any DB work. `fast-mempalace` defers the LLM context entirely and goes straight to `sqlite-vec`.

| Engine | Command | Time | Peak RAM |
| ------ | ------- | ---- | -------- |
| 🐢 `mempalace` (Python) | `mempalace init` | 1.40 s | 50.15 MB |
| ⚡ `fast-mempalace` (Zig) | `fast-mempalace stats` | **0.01 s** | **8.40 MB** |

## 2. Neural ingestion — OmniVoice corpus

Corpus from the [OmniVoice](https://github.com/nineninesevenfour/OmniVoice-Studio) repo — all `.py`, `.md`, `.yaml`, `.toml` files concatenated (**450 368 bytes across 56 files → 1 171 drawers**). Apples-to-apples: same bytes, same embedder, same drawer-chunking.

| Engine | Command | Time | Peak RAM |
| ------ | ------- | ---- | -------- |
| 🐢 `mempalace` (Python) | `mempalace mine` | ~120 s (blocks on ChromaDB) | ~320 MB |
| ⚡ `fast-mempalace` (Zig) | `fast-mempalace mine` | **0.59 s** | **95 MB** |

Python blocks on I/O mapping across arrays and pushes system RAM into the hundreds of MB. Zig decouples I/O via `std.Io.Group` concurrency and maps matrices into the Metal API.

## 3. Semantic clustering — search

Mathematical proximity sort against the full DB geometry. Memory deltas are astronomical because `fast-mempalace` binds statically against `sqlite-vec`.

| Engine | Command | Time | Peak RAM |
| ------ | ------- | ---- | -------- |
| 🐢 `mempalace` (Python) | `mempalace search` | 0.78 s | 270 MB |
| ⚡ `fast-mempalace` (Zig) | `fast-mempalace search` | **0.59 s** | **94 MB** |

## 4. Extended commands

Pure execution paths that never touch the embedder.

| Engine | Command | Time | Peak RAM |
| ------ | ------- | ---- | -------- |
| 🐢 `mempalace` (Python) | `mempalace wake-up` | 0.53 s | 76 MB |
| ⚡ `fast-mempalace` (Zig) | `fast-mempalace kg` | **0.02 s** | **8.40 MB** |

## Reproducing

```bash
# Build fast-mempalace
zig build --release=fast

# Mine the OmniVoice corpus
find /path/to/OmniVoice -type f \( -name "*.py" -o -name "*.md" -o -name "*.yaml" -o -name "*.toml" \) \
  | xargs cat > corpus.txt
/usr/bin/time -l ./zig-out/bin/fast-mempalace mine corpus.txt omnivoice

# Run the Python baseline (for comparison rows above)
pip install mempalace
/usr/bin/time -l mempalace mine corpus.txt
```
