# Benchmarks

Microbenchmarks (Benchee) for finding where `IOData` is slow. Run with
`mix run` so the protocol is consolidated:

| script | what it measures |
|---|---|
| `bench/list.exs` | every op of the List impl across iolist shapes (flat, nested, charlist, mixed) |
| `bench/candidates.exs` | the List impl vs. candidate rewrites in `support/candidates.exs` (checked for agreement first) |
| `bench/bitstring.exs` | protocol/wrapper overhead over the BIFs; `starts_with?` algorithms |
| `bench/slice.exs` | sequential-parse workloads via split / Slice / offsets; individual Slice ops |
| `bench/file.exs` | the file impls (`IOData.File`), raw vs. non-raw handles |

Inputs live in `support/inputs.exs`; shapes are named for the code that produces them
(`left` = `[acc, chunk]` appends, `improper` = `[acc | chunk]`, `right` = recursive
builders, `tree` = template output).
