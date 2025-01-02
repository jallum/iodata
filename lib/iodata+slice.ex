defimpl IOData, for: IOData.Slice do
  alias IOData.Slice

  def at_least?(%{count: nil} = slice, n_bytes),
    do: IOData.at_least?(slice.iodata, slice.start + n_bytes)

  def at_least?(slice, n_bytes), do: slice.count >= n_bytes

  def size(%{count: nil} = slice), do: IOData.size(slice.iodata) - slice.start

  def size(slice), do: slice.count

  def split(%{count: nil} = slice, at) do
    {:ok,
     {
       Slice.wrap(slice.iodata, slice.start, at),
       Slice.wrap(slice.iodata, slice.start + at)
     }}
  end

  def split(slice, at) when not is_nil(slice.count) and at > slice.count,
    do: {:error, :insufficient_data}

  def split(slice, at) do
    {:ok,
     {
       %Slice{iodata: slice.iodata, start: slice.start, count: at},
       %Slice{iodata: slice.iodata, start: slice.start + at, count: slice.count - at}
     }}
  end

  def split!(%{count: nil} = slice, at) do
    case split(slice, at) do
      {:ok, result} -> result
      {:error, reason} -> raise ArgumentError, message: "#{reason}"
    end
  end

  def starts_with?(slice, prefix) do
    case to_binary(slice, 0, byte_size(prefix)) do
      {:ok, data} -> data == prefix
      {:error, _} -> false
    end
  end

  def to_iodata(slice), do: IOData.to_iodata(slice.iodata, slice.start, slice.count)

  def to_iodata(slice, start, count),
    do: IOData.to_iodata(slice.iodata, slice.start + start, count)

  def to_iodata!(slice), do: IOData.to_iodata!(slice.iodata, slice.start, slice.count)

  def to_iodata!(slice, start, count),
    do: IOData.to_iodata!(slice.iodata, slice.start + start, count)

  def to_binary(slice), do: IOData.to_binary(slice.iodata, slice.start, slice.count)

  def to_binary(slice, start, count),
    do: IOData.to_binary(slice.iodata, slice.start + start, count)

  def to_binary!(slice), do: IOData.to_binary!(slice.iodata, slice.start, slice.count)

  def to_binary!(slice, start, count),
    do: IOData.to_binary!(slice.iodata, slice.start + start, count)
end
