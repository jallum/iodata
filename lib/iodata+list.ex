defimpl IOData, for: List do
  @moduledoc """
  Implementation of the `IOData` protocol for `iolist`.

  These functions treat lists as IOLists, providing utilities to check sizes,
  split data, and convert to binaries or iodata without unnecessary copying.
  """

  def at_least?(_data, 0), do: true
  def at_least?([], _bytes), do: false

  def at_least?(data, bytes) do
    case next(data) do
      {byte, rest} when is_integer(byte) ->
        at_least?(rest, bytes - 1)

      {binary, rest} when is_binary(binary) ->
        binary_size = byte_size(binary)

        if bytes <= binary_size do
          true
        else
          at_least?(rest, bytes - binary_size)
        end
    end
  end

  def size([]), do: 0
  def size(data), do: :erlang.iolist_size(data)

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

  def split([], 0), do: {:ok, {[], []}}
  def split([], _), do: {:error, :insufficient_data}

  def split(data, at) do
    case do_split(data, at) do
      :eol -> {:error, :insufficient_data}
      {prefix, suffix} -> {:ok, {prefix, suffix}}
    end
  end

  def split!(data, at) do
    case split(data, at) do
      {:ok, {prefix, suffix}} -> {prefix, suffix}
      {:error, reason} -> raise ArgumentError, message: "#{reason}", term: data
    end
  end

  defp do_split(iolist, 0), do: {[], iolist}
  defp do_split([], _), do: {[], []}

  defp do_split(iolist, n) do
    case next(iolist) do
      :eol ->
        :eol

      {byte, rest} when is_integer(byte) ->
        if n == 1 do
          {[byte], rest}
        else
          {left, right} = do_split(rest, n - 1)
          {[byte | left], right}
        end

      {chunk, rest} ->
        chunk_size = byte_size(chunk)

        if chunk_size <= n do
          {left, right} = do_split(rest, n - chunk_size)
          {[chunk | left], right}
        else
          left_chunk = binary_part(chunk, 0, n)
          right_chunk = binary_part(chunk, n, chunk_size - n)
          {[left_chunk], [right_chunk | rest]}
        end
    end
  end

  def starts_with?(_, <<>>), do: true

  def starts_with?(data, value) do
    case next(data) do
      :eol ->
        false

      {byte, rest} when is_integer(byte) ->
        case value do
          <<^byte::8, rest_of_value::binary>> ->
            starts_with?(rest, rest_of_value)

          _ ->
            false
        end

      {binary, rest} when is_binary(binary) ->
        binary_size = byte_size(binary)
        value_size = byte_size(value)

        case :binary.longest_common_prefix([binary, value]) do
          ^binary_size ->
            starts_with?(rest, binary_part(value, binary_size, value_size - binary_size))

          ^value_size ->
            true

          _ ->
            false
        end
    end
  end

  def to_iodata(data), do: {:ok, data}

  def to_iodata!(data), do: data

  def to_iodata(data, start, count) do
    [data]
    |> seek(start)
    |> case do
      {t, 0} ->
        gather(t, count)
        |> case do
          {[bin], _} when is_binary(bin) -> {:ok, bin}
          {iolist, _} -> {:ok, iolist}
        end

      _ ->
        {:error, :insufficient_data}
    end
  end

  def to_iodata!(data, start, count) do
    case to_iodata(data, start, count) do
      {:ok, iolist} -> iolist
      {:error, reason} -> raise ArgumentError, message: "#{reason}", term: data
    end
  end

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
      {:ok, iolist} -> iolist
      {:error, reason} -> raise ArgumentError, message: "#{reason}", term: data
    end
  end

  defp seek([], n), do: {[], n}
  defp seek(iolist, 0), do: {iolist, 0}

  defp seek(iolist, n) do
    case next(iolist) do
      :eol ->
        {[], n}

      {byte, rest} when is_integer(byte) ->
        if n > 1 do
          seek(rest, n - 1)
        else
          {rest, 0}
        end

      {chunk, rest} ->
        chunk_size = byte_size(chunk)

        if chunk_size > n do
          {[binary_part(chunk, n, chunk_size - n) | rest], 0}
        else
          seek(rest, n - chunk_size)
        end
    end
  end

  defp gather([], n), do: {[], n}
  defp gather(_, 0), do: {[], 0}

  defp gather(iolist, n) do
    case next(iolist) do
      :eol ->
        {[], n}

      {byte, rest} when is_integer(byte) ->
        if n == 1 do
          {[byte], 0}
        else
          {nchunk, nn} = gather(rest, n - 1)
          {[byte | nchunk], nn}
        end

      {chunk, rest} ->
        chunk_size = byte_size(chunk)

        if chunk_size > n do
          {[binary_part(chunk, 0, n)], 0}
        else
          {nchunk, nn} = gather(rest, n - chunk_size)
          {[chunk | nchunk], nn}
        end
    end
  end

  defp next([]), do: :eol
  defp next([[] | tail]), do: next(tail)
  defp next([<<>> | tail]), do: next(tail)
  defp next([head | tail]) when is_integer(head) or is_binary(head), do: {head, tail}

  defp next([head | tail]) when is_list(head) do
    case next(head) do
      :eol -> next(tail)
      {chunk, rest} -> {chunk, [rest | tail]}
    end
  end

  defp next(binary) when is_binary(binary), do: {binary, []}
end
