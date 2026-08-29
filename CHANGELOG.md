# Changelog

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
