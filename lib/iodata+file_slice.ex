defimpl IOData, for: File.Slice do
  def at_least?(slice, n_bytes), do: slice.count >= n_bytes

  def size(slice), do: slice.count

  def split(slice, at) when at > slice.count,
    do: {:error, :insufficient_data}

  def split(slice, 0), do: {:ok, {<<>>, slice}}

  def split(slice, at) do
    {:ok,
     {
       %File.Slice{file: slice.file, start: slice.start, count: at},
       %File.Slice{file: slice.file, start: slice.start + at, count: slice.count - at}
     }}
  end

  def split!(slice, at) do
    case split(slice, at) do
      {:ok, slices} -> slices
      {:error, reason} -> raise ArgumentError, message: "#{reason}"
    end
  end

  def starts_with?(_, <<>>), do: true

  def starts_with?(slice, prefix) when byte_size(prefix) > slice.count,
    do: false

  def starts_with?(slice, prefix) do
    case to_binary(slice, 0, byte_size(prefix)) do
      {:ok, data} -> data == prefix
      {:error, _} -> false
    end
  end

  def to_iodata(slice), do: to_binary(slice)
  def to_iodata!(slice), do: to_binary!(slice)

  def to_iodata(slice, start, count), do: to_binary(slice, start, count)
  def to_iodata!(slice, start, count), do: to_binary!(slice, start, count)

  def to_binary(slice) when slice.count == 0, do: {:ok, <<>>}

  def to_binary(slice) do
    case :file.pread(slice.file, slice.start, slice.count) do
      {:ok, data} -> {:ok, data}
      :eof -> {:error, :eof}
      {:error, reason} -> {:error, reason}
    end
  end

  def to_binary!(slice) do
    case to_binary(slice) do
      {:ok, data} -> data
      {:error, reason} -> raise ArgumentError, message: "unexpected error: #{reason}"
    end
  end

  def to_binary(slice, start, count) when start + count > slice.count,
    do: {:error, :insufficient_data}

  def to_binary(slice, start, count) do
    case :file.pread(slice.file, slice.start + start, count) do
      {:ok, data} -> {:ok, data}
      :eof -> {:error, :eof}
      {:error, reason} -> {:error, reason}
    end
  end

  def to_binary!(slice, start, count) do
    case to_binary(slice, start, count) do
      {:ok, data} ->
        data

      {:error, reason} ->
        raise ArgumentError, message: "unexpected error: #{reason}"
    end
  end
end
