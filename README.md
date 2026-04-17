# 🏛️ MemPalace

A heavily optimized, zero-dependency, local-first AI memory system written natively in Zig 0.16.0.

MemPalace serves as an ultra-fast, SQLite-backed Vector Database capable of ingesting your local files dynamically using concurrent mining buffers, vectorizing the text natively on Apple Silicon GPUs (via embedded `llama.cpp` Metal API hooks), and ranking contextual retrieval operations via synchronous LLM endpoints.

## 🚀 The Architecture (Phase 2)

MemPalace explicitly abandons bloated Python toolchains, Bazel compilation layers, and opaque runtime servers in favor of mathematical hardware isolation:

* **Zero-Dependency Core:** Everything maps cleanly against standard `zig build`.
* **Sub-Millisecond Retrieval:** Powered by `sqlite-vec` natively memory-mapped using `PRAGMA mmap_size=512MB` for instant semantic clustering.
* **Bare-Metal Vector Generation:** `llama.cpp` is linked *statically* via CMake natively inside `build.zig`, ensuring 100% pure hardware execution on **Apple Silicon (Metal)** and **Linux (CUDA)** without external bridging plugins.
* **Concurrent Mining:** Dynamic multi-threading file processing pipelines built with Zig's bleeding-edge `std.Io.Group` arrays.
* **Native HTTP LLM Reranking:** Leverages `std.http.Client` natively against local LLM backends (like Ollama) to re-score vector clusters instantly.

## 📦 Usage

### 1. Build the Binary
Compilation requires a `.gguf` embedding model in the `lib` directory (e.g. `nomic-embed-text`) and `cmake` for compiling the backend natively.

```bash
# Downloads llama.cpp dependencies and compiles Native Metal/CUDA backends
zig build --release=fast
```

### 2. Configuration (`mempalace.yaml`)
Backwards compatible configuration block natively bypassing generic dependencies.

```yaml
database_path: "mempalace.db"
model_path: "lib/minilm.gguf"
default_wing: "production"
ignore_patterns:
  - ".git"
  - ".zig-cache"
```

### 3. Mine a Directory
Launch the concurrent tokenizer buffer targeting any raw codebase.
```bash
./zig-out/bin/mempalace mine /path/to/codebase
```

### 4. Search Vectors
Run native vector-distance SQL commands mathematically against local data.
```bash
./zig-out/bin/mempalace search "Where is the HTTP reranker configured?"
```
