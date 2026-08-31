defmodule IOData.Bench.Candidates.List do
  @moduledoc """
  Alternative implementations of the List hot paths, used by candidates.exs
  to measure what a rewrite would buy. Nothing here is wired into the library.

  `Walk` replaces `next/1` (which allocates a tuple and re-wraps the remaining
  structure on every element) with a tail-recursive traversal that keeps the
  pending tails on an explicit stack. Each element costs one cons at most, and
  nesting depth is paid once per sublist rather than once per element.

  `Bif` variants lean on `:erlang.iolist_size/1` / `:erlang.iolist_to_binary/1`
  and copy when needed; they set the bar for "just let C do it".
  """

  defmodule Walk do
    # --- at_least? -------------------------------------------------------

    def at_least?(_data, 0), do: true
    def at_least?(data, n), do: al(data, [], n)

    defp al(_, _, n) when n <= 0, do: true
    defp al([], [], _n), do: false
    defp al([], [k | ks], n), do: al(k, ks, n)
    defp al([h | t], ks, n) when is_binary(h), do: al(t, ks, n - byte_size(h))
    defp al([h | t], ks, n) when is_integer(h), do: al(t, ks, n - 1)
    defp al([h | t], ks, n) when is_list(h), do: al(h, [t | ks], n)
    defp al(b, ks, n) when is_binary(b), do: al([], ks, n - byte_size(b))

    # --- split -----------------------------------------------------------

    def split(data, at), do: sp(data, [], at, [])

    defp sp(rest, ks, 0, acc), do: {:ok, {:lists.reverse(acc), resume(rest, ks)}}
    defp sp([], [], _n, _acc), do: {:error, :insufficient_data}
    defp sp([], [k | ks], n, acc), do: sp(k, ks, n, acc)

    defp sp([h | t], ks, n, acc) when is_binary(h) do
      s = byte_size(h)

      if s <= n do
        sp(t, ks, n - s, [h | acc])
      else
        {:ok,
         {:lists.reverse([binary_part(h, 0, n) | acc]),
          resume([binary_part(h, n, s - n) | t], ks)}}
      end
    end

    defp sp([h | t], ks, n, acc) when is_integer(h), do: sp(t, ks, n - 1, [h | acc])
    defp sp([h | t], ks, n, acc) when is_list(h), do: sp(h, [t | ks], n, acc)
    defp sp(b, ks, n, acc) when is_binary(b), do: sp([b], ks, n, acc)

    defp resume(rest, []), do: rest
    defp resume(rest, ks), do: [rest | ks]

    # --- to_iodata / to_binary --------------------------------------------

    def to_iodata(data, start, count) do
      case seek(data, [], start) do
        {rest, ks} -> gather(rest, ks, count, [])
        :eol -> {:error, :insufficient_data}
      end
    end

    def to_binary(data, start, count) do
      case to_iodata(data, start, count) do
        {:ok, io} -> {:ok, :erlang.iolist_to_binary(io)}
        err -> err
      end
    end

    defp seek(rest, ks, 0), do: {rest, ks}
    defp seek([], [], _n), do: :eol
    defp seek([], [k | ks], n), do: seek(k, ks, n)

    defp seek([h | t], ks, n) when is_binary(h) do
      s = byte_size(h)
      if s <= n, do: seek(t, ks, n - s), else: {[binary_part(h, n, s - n) | t], ks}
    end

    defp seek([h | t], ks, n) when is_integer(h), do: seek(t, ks, n - 1)
    defp seek([h | t], ks, n) when is_list(h), do: seek(h, [t | ks], n)
    defp seek(b, ks, n) when is_binary(b), do: seek([b], ks, n)

    defp gather(_rest, _ks, 0, acc), do: {:ok, finish(acc)}
    defp gather([], [], _n, _acc), do: {:error, :insufficient_data}
    defp gather([], [k | ks], n, acc), do: gather(k, ks, n, acc)

    defp gather([h | t], ks, n, acc) when is_binary(h) do
      s = byte_size(h)

      if s <= n,
        do: gather(t, ks, n - s, [h | acc]),
        else: {:ok, finish([binary_part(h, 0, n) | acc])}
    end

    defp gather([h | t], ks, n, acc) when is_integer(h), do: gather(t, ks, n - 1, [h | acc])
    defp gather([h | t], ks, n, acc) when is_list(h), do: gather(h, [t | ks], n, acc)
    defp gather(b, ks, n, acc) when is_binary(b), do: gather([b], ks, n, acc)

    defp finish([bin]) when is_binary(bin), do: bin
    defp finish(acc), do: :lists.reverse(acc)

    # --- starts_with? ------------------------------------------------------

    def starts_with?(data, prefix), do: sw(data, [], prefix)

    defp sw(_, _, <<>>), do: true
    defp sw([], [], _p), do: false
    defp sw([], [k | ks], p), do: sw(k, ks, p)

    defp sw([h | t], ks, p) when is_binary(h) do
      s = byte_size(h)
      ps = byte_size(p)

      if s >= ps do
        binary_part(h, 0, ps) == p
      else
        case p do
          <<^h::binary-size(s), pr::binary>> -> sw(t, ks, pr)
          _ -> false
        end
      end
    end

    defp sw([h | t], ks, <<h::8, pr::binary>>) when is_integer(h), do: sw(t, ks, pr)
    defp sw([h | _], _ks, _p) when is_integer(h), do: false
    defp sw([h | t], ks, p) when is_list(h), do: sw(h, [t | ks], p)
    defp sw(b, ks, p) when is_binary(b), do: sw([b], ks, p)
  end

  defmodule Bif do
    def at_least?(data, n), do: :erlang.iolist_size(data) >= n

    def split(data, at) do
      bin = :erlang.iolist_to_binary(data)

      if at <= byte_size(bin),
        do: {:ok, :erlang.split_binary(bin, at)},
        else: {:error, :insufficient_data}
    end

    def to_binary(data, start, count) do
      bin = :erlang.iolist_to_binary(data)

      if start + count <= byte_size(bin),
        do: {:ok, binary_part(bin, start, count)},
        else: {:error, :insufficient_data}
    end

    def starts_with?(data, prefix) do
      ps = byte_size(prefix)
      bin = :erlang.iolist_to_binary(data)
      byte_size(bin) >= ps and binary_part(bin, 0, ps) == prefix
    end
  end
end
