defimpl IOData, for: List do
  @moduledoc """
  Implementation of the `IOData` protocol for `iolist`.

  These functions treat lists as IOLists, providing utilities to check sizes,
  split data, and convert to binaries or iodata without unnecessary copying.

  ## Traversal

  Every walk below is tail-recursive over the current list with an explicit
  stack (`ks`) of the tails still to be visited. Descending into a nested list
  pushes the enclosing tail; reaching `[]` pops one. This costs one cons per
  sublist rather than one tuple + cons per *element*, and it never re-wraps the
  structure, so nesting depth is paid once, not once per element. Improper
  tails (`[a | "bin"]`) are handled by treating a bare binary as a one-element
  list.
  """

  # -- at_least? ---------------------------------------------------------------

  def at_least?(_data, 0), do: true
  def at_least?(data, n), do: at_least(data, [], n)

  defp at_least(_, _, n) when n <= 0, do: true
  defp at_least([], [], _n), do: false
  defp at_least([], [k | ks], n), do: at_least(k, ks, n)
  defp at_least([h | t], ks, n) when is_binary(h), do: at_least(t, ks, n - byte_size(h))
  defp at_least([h | t], ks, n) when is_integer(h), do: at_least(t, ks, n - 1)
  defp at_least([h | t], ks, n) when is_list(h), do: at_least(h, [t | ks], n)
  defp at_least(b, ks, n) when is_binary(b), do: at_least([], ks, n - byte_size(b))

  # -- size --------------------------------------------------------------------

  def size(data), do: :erlang.iolist_size(data)

  # -- slice -------------------------------------------------------------------

  def slice(data, {start, count}), do: to_iodata(data, start, count)
  def slice(data, start, count), do: to_iodata(data, start, count)

  def slice!(data, start_count) do
    case slice(data, start_count) do
      {:ok, slice} -> slice
      {:error, reason} -> raise ArgumentError, message: "#{reason}"
    end
  end

  def slice!(data, start, count) do
    case slice(data, start, count) do
      {:ok, slice} -> slice
      {:error, reason} -> raise ArgumentError, message: "#{reason}"
    end
  end

  # -- split -------------------------------------------------------------------

  def split(data, at), do: split(data, [], at, [])

  def split!(data, at) do
    case split(data, at) do
      {:ok, {prefix, suffix}} -> {prefix, suffix}
      {:error, reason} -> raise ArgumentError, message: "#{reason}"
    end
  end

  defp split(rest, ks, 0, acc), do: {:ok, {:lists.reverse(acc), resume(rest, ks)}}
  defp split([], [], _n, _acc), do: {:error, :insufficient_data}
  defp split([], [k | ks], n, acc), do: split(k, ks, n, acc)

  defp split([h | t], ks, n, acc) when is_binary(h) do
    size = byte_size(h)

    if size <= n do
      split(t, ks, n - size, [h | acc])
    else
      prefix = :lists.reverse([binary_part(h, 0, n) | acc])
      suffix = resume([binary_part(h, n, size - n) | t], ks)
      {:ok, {prefix, suffix}}
    end
  end

  defp split([h | t], ks, n, acc) when is_integer(h), do: split(t, ks, n - 1, [h | acc])
  defp split([h | t], ks, n, acc) when is_list(h), do: split(h, [t | ks], n, acc)
  defp split(b, ks, n, acc) when is_binary(b), do: split([b], ks, n, acc)

  # Rebuild the unvisited remainder as an iolist: what's left of the current
  # list, followed by every pending tail.
  defp resume([], [k | ks]), do: resume(k, ks)
  defp resume(rest, []) when is_list(rest), do: rest
  defp resume(rest, ks), do: [rest | ks]

  # -- starts_with? ------------------------------------------------------------

  def starts_with?(data, prefix), do: starts_with(data, [], prefix)

  defp starts_with(_, _, <<>>), do: true
  defp starts_with([], [], _prefix), do: false
  defp starts_with([], [k | ks], prefix), do: starts_with(k, ks, prefix)

  defp starts_with([h | t], ks, prefix) when is_binary(h) do
    size = byte_size(h)
    prefix_size = byte_size(prefix)

    if size >= prefix_size do
      binary_part(h, 0, prefix_size) == prefix
    else
      case prefix do
        <<^h::binary-size(size), rest::binary>> -> starts_with(t, ks, rest)
        _ -> false
      end
    end
  end

  defp starts_with([h | t], ks, <<h::8, rest::binary>>) when is_integer(h),
    do: starts_with(t, ks, rest)

  defp starts_with([h | _], _ks, _prefix) when is_integer(h), do: false
  defp starts_with([h | t], ks, prefix) when is_list(h), do: starts_with(h, [t | ks], prefix)
  defp starts_with(b, ks, prefix) when is_binary(b), do: starts_with([b], ks, prefix)

  # -- to_iodata ---------------------------------------------------------------

  def to_iodata(data), do: {:ok, data}

  def to_iodata!(data), do: data

  def to_iodata(data, start, nil) do
    case seek(data, [], start) do
      {rest, ks} -> {:ok, resume(rest, ks)}
      :eol -> {:error, :insufficient_data}
    end
  end

  def to_iodata(data, start, count) do
    case seek(data, [], start) do
      {rest, ks} -> gather(rest, ks, count, [])
      :eol -> {:error, :insufficient_data}
    end
  end

  def to_iodata!(data, start, count) do
    case to_iodata(data, start, count) do
      {:ok, iolist} -> iolist
      {:error, reason} -> raise ArgumentError, message: "#{reason}"
    end
  end

  # Advance `n` bytes; returns the remainder as {current_list, pending_tails}.
  defp seek(rest, ks, 0), do: {rest, ks}
  defp seek([], [], _n), do: :eol
  defp seek([], [k | ks], n), do: seek(k, ks, n)

  defp seek([h | t], ks, n) when is_binary(h) do
    size = byte_size(h)

    if size <= n do
      seek(t, ks, n - size)
    else
      {[binary_part(h, n, size - n) | t], ks}
    end
  end

  defp seek([h | t], ks, n) when is_integer(h), do: seek(t, ks, n - 1)
  defp seek([h | t], ks, n) when is_list(h), do: seek(h, [t | ks], n)
  defp seek(b, ks, n) when is_binary(b), do: seek([b], ks, n)

  # Collect the next `n` bytes into a flat iolist (or a single binary when the
  # range lies within one chunk).
  defp gather(_rest, _ks, 0, acc), do: {:ok, finish(acc)}
  defp gather([], [], _n, _acc), do: {:error, :insufficient_data}
  defp gather([], [k | ks], n, acc), do: gather(k, ks, n, acc)

  defp gather([h | t], ks, n, acc) when is_binary(h) do
    size = byte_size(h)

    if size <= n do
      gather(t, ks, n - size, [h | acc])
    else
      {:ok, finish([binary_part(h, 0, n) | acc])}
    end
  end

  defp gather([h | t], ks, n, acc) when is_integer(h), do: gather(t, ks, n - 1, [h | acc])
  defp gather([h | t], ks, n, acc) when is_list(h), do: gather(h, [t | ks], n, acc)
  defp gather(b, ks, n, acc) when is_binary(b), do: gather([b], ks, n, acc)

  defp finish([bin]) when is_binary(bin), do: bin
  defp finish(acc), do: :lists.reverse(acc)

  # -- to_binary ---------------------------------------------------------------

  def to_binary(data), do: {:ok, :erlang.list_to_binary(data)}

  def to_binary(data, start, count) do
    case to_iodata(data, start, count) do
      {:ok, iolist} -> {:ok, :erlang.iolist_to_binary(iolist)}
      {:error, reason} -> {:error, reason}
    end
  end

  def to_binary!(data), do: :erlang.list_to_binary(data)

  def to_binary!(data, start, count) do
    case to_binary(data, start, count) do
      {:ok, binary} -> binary
      {:error, reason} -> raise ArgumentError, message: "#{reason}"
    end
  end
end
