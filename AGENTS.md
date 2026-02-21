# Repository Guidelines

## Project Structure & Module Organization
- Core source lives at the repo root as `.lisp` files (e.g., `graph.lisp`, `transactions.lisp`) and is wired together by `graph-db.asd`.
- `demo/` contains example schemas and sample applications; `example.lisp` is a larger end-to-end walkthrough.
- Manual test helpers live in `test.lisp`, `test-lhash.lisp`, `test-mop.lisp`, and `xach-test.lisp`.
- `ocicl/` contains vendored dependencies; treat it as third-party code unless you are intentionally updating a dependency.

## Build, Test, and Development Commands
- Load the system in a REPL:
  - `sbcl --eval '(ql:quickload :graph-db)' --quit`
  - or inside a REPL: `(asdf:load-system :graph-db)`
- Run the example walkthrough:
  - `sbcl --eval '(ql:quickload :graph-db)' --load example.lisp`
- Load demo systems by opening the REPL and `(asdf:load-system :social-shopping)` after adding `demo/` to ASDF’s search path.

## Coding Style & Naming Conventions
- Follow existing Common Lisp formatting (2-space indentation, aligned keyword lists).
- Use `kebab-case` for functions/variables and `*earmuffs*` for special globals (see `*graph*` usage).
- Keep file names aligned with their primary module (e.g., `views.lisp` for view/index logic).
- No formatter is enforced; prefer small, readable diffs.

## Testing Guidelines
- Tests are ad hoc; load the helper files and call the functions they define.
  - Example: `sbcl --eval '(ql:quickload :graph-db)' --load test.lisp --eval '(test-create)' --quit`
- Many tests write to `/var/tmp/...`; adjust paths in the test files when working locally.
- If you add tests, place them near existing helpers and document how to run them.

## Commit & Pull Request Guidelines
- Commit messages are short, imperative, and sentence case (e.g., “Add Documentation”, “Fix #35”).
- PRs should include: a short problem statement, what changed, how to verify, and any data format or performance impact.
- Include screenshots or logs only when they clarify behavior (e.g., REST output or benchmark deltas).

## Configuration & Data Files
- Graphs write to on-disk directories passed to `make-graph`/`open-graph`; keep those paths outside the repo.
- If you introduce new persistent files, update `README.org` with migration notes when relevant.
