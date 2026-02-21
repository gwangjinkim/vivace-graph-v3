# Codebase Analysis

## High-Level Intent
VivaceGraph is a persistent, memory-mapped graph database implemented in Common Lisp. It targets high-performance traversal on large graphs by combining:
- Custom on-disk structures (mmap, hash tables, skip lists).
- CLOS-backed schema/vertex/edge modeling.
- Optimistic transactions with validation and recovery logs.
- Secondary indexes (“views”) and a Prolog-style query layer.

## File Map (by concern)
- **System + package wiring**: `graph-db.asd`, `package.lisp`, `globals.lisp`.
  - ASDF system definition, exports, feature conditionals, and global constants/specials.
- **Graph core + schema**: `graph.lisp`, `graph-class.lisp`, `schema.lisp`, `node-class.lisp`, `vertex.lisp`, `edge.lisp`, `primitive-node.lisp`.
  - Graph lifecycle, schema definition, node classes, and core CRUD behavior.
- **Storage and serialization**: `mmap.lisp`, `allocator.lisp`, `buffer-pool.lisp`, `pmem.lisp`, `serialize.lisp`.
  - Memory-mapped files, allocators, and custom binary encoding.
- **Indexes and data structures**: `linear-hash.lisp`, `skip-list.lisp`, `index-list.lisp`, `ve-index.lisp`, `vev-index.lisp`, `type-index.lisp`.
  - Primary storage tables and secondary index structures.
- **Transactions and durability**: `transactions.lisp`, `txn-log.lisp`, `transaction-restore.lisp`, `transaction-streaming.lisp`.
  - Read/write sets, validation, recovery, and log persistence.
- **Views (map/reduce)**: `views.lisp`.
  - View definitions, indexing, and on-disk view metadata.
- **Query + traversal**: `traverse.lisp`, `prologc.lisp`, `prolog-functors.lisp`.
  - Graph traversal utilities and Prolog-style query compilation.
- **Operations**: `replication.lisp`, `backup.lisp`, `rest.lisp`.
  - Replication, snapshot/restore, and REST API glue.
- **Examples/tests**: `example.lisp`, `demo/`, `test.lisp`, `test-lhash.lisp`, `test-mop.lisp`, `xach-test.lisp`.

## Key Flows and Where They Live
### Graph lifecycle
- `make-graph` and `open-graph` in `graph.lisp` allocate/open memory maps, indexes, and schema, then set up replication and `.dirty` state.
- `close-graph` snapshots, closes indexes, removes `.dirty`, and shuts down replication.

### Transactions and commit
- `with-transaction` in `transactions.lisp` creates a transaction, tracks read/write sets, retries on validation conflicts, and eventually commits.
- `%commit` handles validation, log persistence (`persist-transaction`), and applying writes to the graph (`apply-transaction`).

### Views / secondary indexes
- `def-view` and related helpers in `views.lisp` define map/reduce logic and store view metadata.
- `compile-view-code` reads and evaluates stored code, then the map function emits key/value pairs via `yield`.

### Query/traversal
- `traverse.lisp` implements traversal primitives over vertices/edges.
- `prologc.lisp` and `prolog-functors.lisp` compile and execute Prolog-style queries against the graph model.

### REST and replication
- `rest.lisp` exposes a Ningle/Clack REST surface and uses shell calls for htpasswd-based auth.
- `replication.lisp` and `transaction-streaming.lisp` stream transaction logs between master/slave graphs.

## Compatibility and Portability Hotspots
The project is portable across SBCL, CCL, and LispWorks, but with notable implementation hooks:
- **MOP and class behavior**: `package.lisp` conditionally imports `sb-mop` or `closer-mop`.
- **Locks and concurrency**: `rw-lock.lisp` implements a custom RW lock for SBCL/LispWorks, while `utilities.lisp` delegates to CCL’s native RW lock.
- **Hash table concurrency**: `graph.lisp`, `views.lisp`, and `globals.lisp` use `:synchronized`, `:shared`, or `:single-thread` options depending on implementation.
- **Memory mapping**: `mmap.lisp` depends on `osicat-posix` and `cffi`, with Linux/Darwin branches for file extension.
- **Shell integration**: `rest.lisp` shells out to `/usr/bin/htpasswd` and `openssl`, which is not portable to non-Unix systems.

If “ANSI-only” portability is the goal, mmap, threading, and MOP usage would need abstracted backends or optional subsystems.

## Design Tradeoffs and Risk Areas (with file refs)
1) **Global dynamic state**  
   `*graph*`, `*transaction*`, and `*view-rv*` (`globals.lisp`, `transactions.lisp`, `views.lisp`) simplify the API but complicate multi-graph concurrency or reentrancy.

2) **Runtime eval of view code**  
   `views.lisp` stores map/reduce code as strings and runs `read-from-string` + `eval`. This risks code injection, debugging complexity, and implementation variance.

3) **Persistence mixed with runtime-specific metadata**  
   `serialize.lisp` defines a custom binary format, while `schema.dat`/`views.dat` are stored via `cl-store` (`graph.lisp`, `views.lisp`). That mix makes migrations and cross-implementation persistence harder.

4) **Hard-coded storage sizing**  
   `make-graph` in `graph.lisp` creates heap/index files at fixed sizes (1 GB each). This is simple but inflexible for constrained environments or large deployments.

5) **Error handling around memory faults**  
   In `mmap.lisp`, memory-fault conditions are caught and retried recursively without a cap or backoff.

6) **Shelling out in REST auth**  
   `rest.lisp` builds shell command strings for `htpasswd`/`openssl`, which is platform-dependent and can be hard to secure or test.

7) **Darwin remap correctness**  
   `extend-mapped-file` on Darwin must avoid closing the fd before remapping; unmap and then remap with the same fd to prevent `mmap` failures.

## Improvement Ideas (prioritized)
Short-term:
- **Portability layer**: centralize all `#+sbcl/# +ccl/# +lispworks` behavior into a dedicated module (locks, MOP, hash-table options, mmap hooks).
- **Safer views**: store view code as s-expressions, validate it, and `compile` to a function without `eval` on raw strings.
- **Configurable storage sizing**: allow heap/index sizes to be provided via parameters or config files.
- **API boundary**: split ASDF systems into `graph-db/core`, `graph-db/views`, `graph-db/rest`, `graph-db/prolog`, `graph-db/replication` to reduce coupling.

Longer-term:
- **Pluggable storage backend**: define a storage protocol so the graph core can target mmap, LMDB, or other backends.
- **Portability-first metadata**: replace `cl-store` with a stable, versioned metadata format for schema/views.
- **Explicit context passing**: reduce reliance on global specials by threading graph/transaction objects through APIs (keep specials as optional convenience).

## Summary
The design is intentionally low-level and performance-focused, with a coherent pipeline from storage to query. The biggest extensibility and portability gains would come from isolating implementation-specific code, tightening the public API surface, and removing runtime `eval` from persistent view definitions.
