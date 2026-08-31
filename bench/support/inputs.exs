defmodule IOData.Bench.Inputs do
  @moduledoc """
  Deterministic inputs for the benchmarks.

  Every iolist shape here is something that shows up in real code:

    * `flat`      – `[bin, bin, bin]`; what you get from `Enum.reverse(acc)`.
    * `left`      – `[[[a, b], c], d]`; what `acc = [acc, chunk]` produces.
    * `improper`  – `[[[a | b] | c] | d]`; what `acc = [acc | chunk]` produces.
    * `right`     – `[a, [b, [c, d]]]`; what recursive builders / `[chunk, acc]` produce.
    * `tree`      – balanced nesting (branching factor 4); what templates (EEx/HEEx) emit.
    * `charlist`  – a list of bytes.
    * `mixed`     – binaries, bytes and small sublists interleaved.
  """

  @doc "n distinct binaries of `size` bytes, from a fixed seed."
  def chunks(n, size) do
    :rand.seed(:exsss, {n, size, 42})
    for _ <- 1..n, do: :rand.bytes(size)
  end

  def flat(n, size), do: chunks(n, size)
  def left(n, size), do: Enum.reduce(chunks(n, size), [], &[&2, &1])
  def improper(n, size), do: Enum.reduce(chunks(n, size), [], &[&2 | &1])
  def right(n, size), do: chunks(n, size) |> Enum.reverse() |> Enum.reduce([], &[&1, &2])

  def tree(n, size, arity \\ 4), do: chunks(n, size) |> build_tree(arity)

  defp build_tree(items, arity) when length(items) <= arity, do: items

  defp build_tree(items, arity) do
    items
    |> Enum.chunk_every(arity)
    |> Enum.map(&build_tree(&1, arity))
    |> build_tree(arity)
  end

  def charlist(n) do
    :rand.seed(:exsss, {n, 1, 42})
    for _ <- 1..n, do: :rand.uniform(256) - 1
  end

  def mixed(n, size) do
    :rand.seed(:exsss, {n, size, 7})

    for i <- 1..n do
      case rem(i, 4) do
        0 -> :rand.uniform(256) - 1
        1 -> [:rand.bytes(size), [:rand.uniform(256) - 1]]
        _ -> :rand.bytes(size)
      end
    end
  end

  @doc """
  Wraps a datum with the parameters each op needs (total size, midpoint,
  a prefix that spans several leading chunks, ...).
  """
  def describe(data) do
    size = :erlang.iolist_size(data)
    {:ok, prefix} = IOData.to_binary(data, 0, min(size, 100))

    %{
      data: data,
      size: size,
      mid: div(size, 2),
      quarter: div(size, 4),
      prefix: prefix,
      bad_prefix: <<255 - :binary.first(prefix)>> <> binary_part(prefix, 1, byte_size(prefix) - 1)
    }
  end

  @doc "The standard iolist inputs used by list.exs and candidates.exs."
  def iolists do
    %{
      "flat  8 x 16B" => flat(8, 16),
      "flat  64 x 64B" => flat(64, 64),
      "flat  1024 x 1KB" => flat(1024, 1024),
      "charlist 4KB" => charlist(4096),
      "mixed 256 x 16B" => mixed(256, 16),
      "tree  256 x 64B" => tree(256, 64),
      "left  256 x 64B" => left(256, 64),
      "improper 256 x 64B" => improper(256, 64),
      "right 256 x 64B" => right(256, 64)
    }
    |> Map.new(fn {k, v} -> {k, describe(v)} end)
  end

  def binaries do
    %{
      "bin 16B (heap)" => :binary.copy(<<7>>, 16),
      "bin 4KB" => :binary.copy(<<7>>, 4096),
      "bin 1MB" => :binary.copy(<<7>>, 1024 * 1024)
    }
    |> Map.new(fn {k, v} -> {k, describe(v)} end)
  end

  def bench_opts(overrides \\ []) do
    Keyword.merge(
      [
        warmup: 0.5,
        time: 1.5,
        memory_time: 0.5,
        print: [configuration: false],
        formatters: [{Benchee.Formatters.Console, extended_statistics: false}]
      ],
      overrides
    )
  end

  @doc """
  Raise unless every candidate agrees with the reference on every input.

  Returns the inputs on which the reference itself does not raise, so callers
  can still time the reference where it works. Inputs it raises on are reported
  and dropped (the current List impl has known crashes on some nested shapes).
  """
  def check!(inputs, ref, candidates) do
    Enum.reduce(inputs, %{}, fn {name, input}, acc ->
      case safe(ref, input) do
        {:raised, e} ->
          IO.puts("  ! current impl raises #{inspect(e)} on #{inspect(name)} — excluded")
          acc

        expected ->
          for {cname, cand} <- candidates do
            got = safe(cand, input)

            if normalize(expected) != normalize(got) do
              raise "candidate #{inspect(cname)} disagrees on #{inspect(name)}:\n  expected #{inspect(expected, limit: 8)}\n  got      #{inspect(got, limit: 8)}"
            end
          end

          Map.put(acc, name, input)
      end
    end)
  end

  defp safe(f, input) do
    f.(input)
  rescue
    e -> {:raised, e.__struct__}
  end

  # Results that are iodata compare by content, not by shape.
  defp normalize({:ok, {a, b}}), do: {:ok, {normalize_io(a), normalize_io(b)}}
  defp normalize({:ok, io}), do: {:ok, normalize_io(io)}
  defp normalize(other), do: other

  defp normalize_io(io) when is_list(io) or is_binary(io), do: IO.iodata_to_binary(io)
  defp normalize_io(other), do: other
end
