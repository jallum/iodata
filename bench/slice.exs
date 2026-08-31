# Sequential-consumption workloads: the pattern a parser uses.
#
#   mix run bench/slice.exs
#
# Consume N fixed-size records from the front of some data, three ways:
#
#   split loop    – `{rec, rest} = IOData.split!(rest, len)` and carry `rest`
#   slice loop    – wrap in IOData.Slice once, then split the *slice* and
#                   `to_binary` each record (the slice re-seeks from the head
#                   of the underlying data every time)
#   offset loop   – keep the original data and an integer offset, calling
#                   `to_binary(data, offset, len)` (also re-seeks every time)
#
# Run over a binary, a flat iolist, and a nested iolist. Look at how each
# strategy scales from n=64 to n=512 records.

Code.require_file("support/inputs.exs", __DIR__)
alias IOData.Bench.Inputs

true = Protocol.consolidated?(IOData) or raise "run with `mix run` so IOData is consolidated"

record = 32

inputs =
  for n <- [64, 512],
      {shape, mk} <- [
        {"binary", &:erlang.iolist_to_binary(Inputs.flat(&1, record))},
        {"flat list", &Inputs.flat(&1, record)},
        {"left-nested list", &Inputs.left(&1, record)}
      ],
      into: %{} do
    {"#{shape} n=#{n}", %{data: mk.(n), n: n}}
  end

split_loop = fn data, n ->
  Enum.reduce(1..n, {[], data}, fn _, {acc, rest} ->
    {rec, rest} = IOData.split!(rest, record)
    {[IOData.to_binary!(rec) | acc], rest}
  end)
  |> elem(0)
end

slice_loop = fn data, n ->
  Enum.reduce(1..n, {[], IOData.Slice.wrap(data, 0, n * record)}, fn _, {acc, rest} ->
    {rec, rest} = IOData.split!(rest, record)
    {[IOData.to_binary!(rec) | acc], rest}
  end)
  |> elem(0)
end

offset_loop = fn data, n ->
  Enum.reduce(1..n, {[], 0}, fn _, {acc, off} ->
    {[IOData.to_binary!(data, off, record) | acc], off + record}
  end)
  |> elem(0)
end

Benchee.run(
  %{
    "split loop" => fn %{data: d, n: n} -> split_loop.(d, n) end,
    "slice loop" => fn %{data: d, n: n} -> slice_loop.(d, n) end,
    "offset loop" => fn %{data: d, n: n} -> offset_loop.(d, n) end
  },
  Inputs.bench_opts(inputs: inputs, memory_time: 0.3)
)

IO.puts("\n=== single Slice ops (wrap once, each op re-derives from the parent) ===")

slice_inputs =
  Map.new(
    [
      {"slice over 64KB binary", :erlang.iolist_to_binary(Inputs.flat(1024, 64))},
      {"slice over flat 1024 x 64B", Inputs.flat(1024, 64)},
      {"slice over left 256 x 64B", Inputs.left(256, 64)}
    ],
    fn {name, d} -> {name, IOData.Slice.wrap(d, 4096, 4096)} end
  )

Benchee.run(
  %{
    "at_least?(100)" => fn s -> IOData.at_least?(s, 100) end,
    "size" => fn s -> IOData.size(s) end,
    "split(2048)" => fn s -> IOData.split(s, 2048) end,
    "starts_with?(16B)" => fn s -> IOData.starts_with?(s, IOData.to_binary!(s, 0, 16)) end,
    "to_binary/1" => fn s -> IOData.to_binary(s) end,
    "to_binary(100, 100)" => fn s -> IOData.to_binary(s, 100, 100) end
  },
  Inputs.bench_opts(inputs: slice_inputs, memory_time: 0.3)
)
