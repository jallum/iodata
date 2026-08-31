# Changelog

## 0.9.0 — 2026-08-31

Performance release: a Benchee suite (under `bench/`) found the `List`
implementation quadratic on nested iolists, slices over lists re-walking
their input on every read, and a handful of crash/correctness bugs on the
way. Details below.

- Rewrote the `List` implementation's traversal. The old walk re-wrapped the
  remaining structure on every element, making `at_least?/2`, `split/2`,
  `starts_with?/2`, `to_iodata/3` and `to_binary/3` quadratic on nested
  iolists (the `[acc, chunk]`, `[acc | chunk]` and `[chunk, acc]` shapes real
  code produces). The new walk keeps pending tails on an explicit stack: on a
  256-chunk left-nested iolist, `split/2` goes from ~167 µs / 966 KB to
  ~1.5 µs / 8 KB; flat lists are 2–3x faster with roughly half the allocation.
- `IOData.Slice.wrap/3` over a list now advances the list to `start` eagerly
  and stores the remainder, instead of re-walking the list from its head on
  every later operation. Consuming a list through successive slices is now
  linear rather than quadratic (512 records over a 512-chunk list: 244 µs →
  ~20 µs). The struct for a list therefore has `start: 0` and a trimmed
  `iodata` — compare slices by content, not by field.
- Added an `IOData` implementation for `:raw` file handles — the
  `{:file_descriptor, _, _}` tuples `:file.open/2` returns with `:raw`. Raw
  handles skip the file-server process, making every read ~3–5x cheaper, but
  can only be used from the process that opened them. Open files in `:binary`
  mode. Any other tuple raises `Protocol.UndefinedError`.

      {:ok, file} = :file.open(path, [:read, :binary, :raw])
      {:ok, header} = IOData.to_binary(file, 0, 64)

- File reads now enforce the protocol's exact-count contract: a range that
  extends past the end of the file returns `{:error, :insufficient_data}`
  instead of a silently truncated `{:ok, _}` (partial overlap) or
  `{:error, :eof}` (fully past the end). `IOData.split/2` on a file validates
  the offset against the file size, so `split!/2` now raises for out-of-range
  offsets; `slice/2,3` remains lazy and errors at read time.
- Fixed `IOData.at_least?/2` on lists raising `CaseClauseError` when a nested
  iolist ran out mid-walk, e.g. `IOData.at_least?([["a"]], 2)`.
- Fixed `to_iodata/3` / `to_binary/3` on lists raising `ArithmeticError` for a
  `nil` count, which broke no-count `IOData.Slice`s over lists — including the
  suffix returned by `IOData.split/2`.
- Fixed `IOData.size/1` on an unreadable file returning `false`, which made
  `at_least?/2` answer `true`; `size/1` now raises `ArgumentError` and
  `at_least?/2` returns `false`.
- Fixed file reads returning charlists for files opened without `:binary`;
  reads are normalized to binaries, which also fixes `starts_with?/2` on
  text-mode files.

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
