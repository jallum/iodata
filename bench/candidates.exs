# Current List implementation vs. candidate rewrites (see support/candidates.exs).
#
#   mix run bench/candidates.exs
#
#   current – lib/iodata+list.ex as-is
#   walk    – explicit-stack traversal, no per-element tuple/re-wrap
#   bif     – iolist_to_binary / iolist_size and copy; the "let C do it" bar
#
# Each candidate is checked for agreement with the current implementation on
# every input before anything is timed.

Code.require_file("support/inputs.exs", __DIR__)
Code.require_file("support/candidates.exs", __DIR__)
alias IOData.Bench.Inputs
alias IOData.Bench.Candidates.List.{Walk, Bif}

inputs = Inputs.iolists()
opts = Inputs.bench_opts(inputs: inputs, memory_time: 0.3)

IO.puts("\n=== at_least?(size + 1) — worst case, must walk everything ===")
ref = fn %{data: d, size: s} -> IOData.at_least?(d, s + 1) end

cands = %{
  "walk" => fn %{data: d, size: s} -> Walk.at_least?(d, s + 1) end,
  "bif  (iolist_size >= n)" => fn %{data: d, size: s} -> Bif.at_least?(d, s + 1) end
}

ok_inputs = Inputs.check!(inputs, ref, cands)
Benchee.run(Map.put(cands, "current", ref), Keyword.put(opts, :inputs, ok_inputs))

IO.puts("\n=== at_least?(16) — best case, answer is in the first chunk(s) ===")
ref = fn %{data: d} -> IOData.at_least?(d, 16) end

cands = %{
  "walk" => fn %{data: d} -> Walk.at_least?(d, 16) end,
  "bif  (iolist_size >= n)" => fn %{data: d} -> Bif.at_least?(d, 16) end
}

ok_inputs = Inputs.check!(inputs, ref, cands)
Benchee.run(Map.put(cands, "current", ref), Keyword.put(opts, :inputs, ok_inputs))

IO.puts("\n=== split(mid) ===")
ref = fn %{data: d, mid: m} -> IOData.split(d, m) end

cands = %{
  "walk" => fn %{data: d, mid: m} -> Walk.split(d, m) end,
  "bif  (iolist_to_binary + split_binary)" => fn %{data: d, mid: m} -> Bif.split(d, m) end
}

ok_inputs = Inputs.check!(inputs, ref, cands)
Benchee.run(Map.put(cands, "current", ref), Keyword.put(opts, :inputs, ok_inputs))

IO.puts("\n=== to_binary(mid, quarter) ===")
ref = fn %{data: d, mid: m, quarter: q} -> IOData.to_binary(d, m, q) end

cands = %{
  "walk" => fn %{data: d, mid: m, quarter: q} -> Walk.to_binary(d, m, q) end,
  "bif  (iolist_to_binary + binary_part)" => fn %{data: d, mid: m, quarter: q} ->
    Bif.to_binary(d, m, q)
  end
}

ok_inputs = Inputs.check!(inputs, ref, cands)
Benchee.run(Map.put(cands, "current", ref), Keyword.put(opts, :inputs, ok_inputs))

IO.puts("\n=== starts_with?(100B prefix) ===")
ref = fn %{data: d, prefix: p} -> IOData.starts_with?(d, p) end

cands = %{
  "walk" => fn %{data: d, prefix: p} -> Walk.starts_with?(d, p) end,
  "bif  (iolist_to_binary + binary_part ==)" => fn %{data: d, prefix: p} ->
    Bif.starts_with?(d, p)
  end
}

ok_inputs = Inputs.check!(inputs, ref, cands)
Benchee.run(Map.put(cands, "current", ref), Keyword.put(opts, :inputs, ok_inputs))
