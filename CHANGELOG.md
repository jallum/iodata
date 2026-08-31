# Changelog

## Unreleased

- Rewrote the `List` implementation's traversal. `next/1` allocated a tuple and
  re-wrapped the remaining structure on every element, which made
  `IOData.at_least?/2`, `IOData.split/2`, `IOData.starts_with?/2`,
  `IOData.to_iodata/3` and `IOData.to_binary/3` quadratic on nested iolists
  (`[acc, chunk]`, `[acc | chunk]`, `[chunk, acc]` shapes). The new walk keeps
  the pending tails on an explicit stack: on a 256-chunk left-nested iolist a
  `split/2` went from ~167 µs / 966 KB to ~1.5 µs / 8 KB, and flat lists are
  2–3x faster with roughly half the allocation.
- Fixed `IOData.at_least?/2` on lists raising `CaseClauseError` when a nested
  iolist ran out mid-walk, e.g. `IOData.at_least?([["a"]], 2)`.
- Fixed `IOData.to_iodata/3` and `IOData.to_binary/3` on lists raising
  `ArithmeticError` for a `nil` count, which broke `IOData.to_binary/1` (and
  friends) on an `IOData.Slice` with no count over a list, e.g.
  `IOData.Slice.wrap(["ab", "cd"], 1)`.
- `IOData.Slice.wrap/3` over a list now advances the list to `start` eagerly
  and stores the remainder, instead of re-walking the list from its head on
  every later operation. Consuming a list through successive slices is now
  linear rather than quadratic (512 records over a 512-chunk list: 244 µs →
  ~20 µs). The struct returned for a list therefore has `start: 0` and a
  trimmed `iodata` — compare by content, not by field.
- Added an `IOData` implementation for `:raw` file handles (the
  `{:file_descriptor, _, _}` tuples `:file.open/2` returns with `:raw`). Raw
  handles skip the file server, making every read ~3-5x cheaper, but can only
  be used from the process that opened them. The PID and tuple impls share
  `IOData.File`. Any other tuple raises `Protocol.UndefinedError`.
- Fixed `IOData.size/1` on a file that cannot be read returning `false`
  (which made `IOData.at_least?/2` answer `true`); it now raises
  `ArgumentError`, and `at_least?/2` returns `false`.
- Fixed `IOData.to_binary/1` (and friends) on the suffix of `IOData.split/2`
  of a file — a slice with no count — passing `nil` as the read length.
- Fixed `IOData.to_binary/3` (and `to_iodata/3`) on files returning a short
  read tagged `{:ok, _}` when the range extended past the end of the file;
  it now returns `{:error, :insufficient_data}`, matching the other
  implementations. Reads entirely past the end also now return
  `{:error, :insufficient_data}` instead of `{:error, :eof}`.
- Fixed file reads returning charlists for files opened without `:binary`;
  reads are normalized to binaries (a no-op for binary-mode files), which
  also fixes `IOData.starts_with?/2` on text-mode files.
- `IOData.split/2` on a file now validates the offset against the file size
  and returns `{:error, :insufficient_data}` (and `split!/2` raises) instead
  of unconditionally succeeding. `slice/2,3` remains lazy; out-of-range
  slices error when read.
- Added a Benchee suite under `bench/` (see `bench/README.md`).

## 0.8.0 — 2026-08-28

- Fixed the `List` implementation silently returning truncated data when a
  requested range extended past the end of the iolist. `IOData.split/2`,
  `IOData.to_iodata/3`, `IOData.to_binary/3`, and `IOData.slice/2,3` on lists
  now return `{:error, :insufficient_data}` for out-of-range requests, matching
  the documented contract and the other implementations. For example,
  `IOData.split(["ab"], 3)` previously returned `{:ok, {["ab"], []}}` — it now
  returns `{:error, :insufficient_data}`.
- Fixed `IOData.split!/2`, `IOData.to_iodata!/3`, and `IOData.to_binary!/3` on
  lists crashing with a `KeyError` instead of raising the intended
  `ArgumentError` when data was insufficient.
