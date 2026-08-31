# The file implementations (`IOData.File`, behind the PID and Tuple impls):
# every op is at least one round trip to the file. Compares a `:raw` handle
# against one served by the file server, and shows the `read_file_info` that
# `size`/`at_least?`/`to_binary/1` cost on top of the read itself.
#
#   mix run bench/file.exs
#
# Set IODATA_BENCH_TMP to control where the scratch file goes.

Code.require_file("support/inputs.exs", __DIR__)
alias IOData.Bench.Inputs

true = Protocol.consolidated?(IOData) or raise "run with `mix run` so IOData is consolidated"

dir = System.get_env("IODATA_BENCH_TMP") || System.tmp_dir!()
path = Path.join(dir, "iodata_bench_#{System.os_time(:millisecond)}.bin")
File.write!(path, :binary.copy(<<7>>, 1024 * 1024))

{:ok, raw} = :file.open(path, [:read, :binary, :raw])
{:ok, cooked} = :file.open(path, [:read, :binary])

try do
  IO.puts("\n=== IOData ops, raw vs. non-raw handle ===")

  # A :raw handle can only be used by the process that opened it, and Benchee
  # measures in its own task, so open it in before_scenario.
  Benchee.run(
    %{
      "size (read_file_info)" => fn f -> IOData.size(f) end,
      "at_least?(1000)" => fn f -> IOData.at_least?(f, 1000) end,
      "starts_with?(16B)" => fn f -> IOData.starts_with?(f, :binary.copy(<<7>>, 16)) end,
      "split(4096) [lazy]" => fn f -> IOData.split(f, 4096) end,
      "to_binary(4096, 64)" => fn f -> IOData.to_binary(f, 4096, 64) end,
      "to_binary(4096, 64KB)" => fn f -> IOData.to_binary(f, 4096, 65536) end,
      "to_binary/1 (1MB)" => fn f -> IOData.to_binary(f) end,
      "ref: pread(4096, 64)" => fn f -> :file.pread(f, 4096, 64) end,
      "ref: pread(0, 1MB)" => fn f -> :file.pread(f, 0, 1024 * 1024) end
    },
    Inputs.bench_opts(
      inputs: %{"raw" => :raw, "non-raw (file server)" => cooked},
      memory_time: 0,
      before_scenario: fn
        :raw -> :file.open(path, [:read, :binary, :raw]) |> elem(1)
        f -> f
      end,
      after_scenario: fn
        ^cooked -> :ok
        f -> :file.close(f)
      end
    )
  )
after
  :file.close(raw)
  :file.close(cooked)
  File.rm(path)
end
