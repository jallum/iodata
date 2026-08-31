# The BitString implementation is mostly BIF wrappers; what's left to measure is
# (a) the cost of the protocol dispatch + tuple wrapping around each BIF and
# (b) `starts_with?`, the one op with a real choice of algorithm.
#
#   mix run bench/bitstring.exs

Code.require_file("support/inputs.exs", __DIR__)
alias IOData.Bench.Inputs

true = Protocol.consolidated?(IOData) or raise "run with `mix run` so IOData is consolidated"

inputs = Inputs.binaries()
opts = Inputs.bench_opts(inputs: inputs, memory_time: 0.3)

IO.puts("\n=== protocol + wrapper overhead vs. the underlying BIF ===")

Benchee.run(
  %{
    "IOData.size" => fn %{data: d} -> IOData.size(d) end,
    "ref: byte_size" => fn %{data: d} -> byte_size(d) end,
    "IOData.at_least?(mid)" => fn %{data: d, mid: m} -> IOData.at_least?(d, m) end,
    "IOData.split(mid)" => fn %{data: d, mid: m} -> IOData.split(d, m) end,
    "ref: :erlang.split_binary(mid)" => fn %{data: d, mid: m} -> :erlang.split_binary(d, m) end,
    "IOData.to_binary(mid, quarter)" => fn %{data: d, mid: m, quarter: q} ->
      IOData.to_binary(d, m, q)
    end,
    "ref: binary_part(mid, quarter)" => fn %{data: d, mid: m, quarter: q} ->
      binary_part(d, m, q)
    end
  },
  opts
)

IO.puts("\n=== starts_with? algorithms ===")

# Same prefix for every input so the comparison is apples to apples.
sw_inputs =
  Map.new(inputs, fn {name, %{data: d} = input} ->
    p = binary_part(d, 0, 16)
    {name, %{input | prefix: p, bad_prefix: <<255 - :binary.first(p)>> <> binary_part(p, 1, 15)}}
  end)

for {label, key} <- [{"match", :prefix}, {"mismatch on byte 0", :bad_prefix}] do
  IO.puts("\n--- #{label} ---")

  Benchee.run(
    %{
      "current: longest_common_prefix" => fn %{data: d} = i -> IOData.starts_with?(d, i[key]) end,
      "binary_part ==" => fn %{data: d} = i ->
        p = i[key]
        ps = byte_size(p)
        byte_size(d) >= ps and binary_part(d, 0, ps) == p
      end,
      "pattern match" => fn %{data: d} = i ->
        p = i[key]
        ps = byte_size(p)

        case d do
          <<^p::binary-size(ps), _::binary>> -> true
          _ -> false
        end
      end,
      "String.starts_with?" => fn %{data: d} = i -> String.starts_with?(d, i[key]) end
    },
    Inputs.bench_opts(inputs: sw_inputs, memory_time: 0)
  )
end
