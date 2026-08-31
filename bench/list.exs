# Where does the List implementation spend its time?
#
#   mix run bench/list.exs
#
# Every job runs against every iolist shape in IOData.Bench.Inputs.iolists/0,
# so the interesting read is *down* a column: the same op on flat vs nested
# input. `:erlang.iolist_size` is included as the "what C can do" reference.

Code.require_file("support/inputs.exs", __DIR__)
alias IOData.Bench.Inputs

true = Protocol.consolidated?(IOData) or raise "run with `mix run` so IOData is consolidated"

Benchee.run(
  %{
    "at_least?(mid)" => fn %{data: d, mid: m} -> IOData.at_least?(d, m) end,
    "at_least?(size) [full walk]" => fn %{data: d, size: s} -> IOData.at_least?(d, s) end,
    "size" => fn %{data: d} -> IOData.size(d) end,
    "split(mid)" => fn %{data: d, mid: m} -> IOData.split(d, m) end,
    "starts_with?(100B prefix)" => fn %{data: d, prefix: p} -> IOData.starts_with?(d, p) end,
    "starts_with?(bad prefix)" => fn %{data: d, bad_prefix: p} -> IOData.starts_with?(d, p) end,
    "to_iodata(mid, quarter)" => fn %{data: d, mid: m, quarter: q} ->
      IOData.to_iodata(d, m, q)
    end,
    "to_binary(mid, quarter)" => fn %{data: d, mid: m, quarter: q} ->
      IOData.to_binary(d, m, q)
    end,
    "to_binary/1" => fn %{data: d} -> IOData.to_binary(d) end,
    "ref: :erlang.iolist_size" => fn %{data: d} -> :erlang.iolist_size(d) end
  },
  Inputs.bench_opts(inputs: Inputs.iolists())
)
