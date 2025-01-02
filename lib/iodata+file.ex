defimpl IOData, for: PID do
  alias IOData.Slice

  def at_least?(file, n_bytes), do: size(file) >= n_bytes

  def size(file) do
    case :file.read_file_info(file) do
      {:ok, info} -> info |> elem(1)
      {:error, _} -> false
    end
  end

  def slice(file, {start, count}), do: {:ok, Slice.wrap(file, start, count)}
  def slice(file, start, count), do: {:ok, Slice.wrap(file, start, count)}

  def slice!(file, {start, count}), do: Slice.wrap(file, start, count)
  def slice!(file, start, count), do: Slice.wrap(file, start, count)

  def split(file, 0), do: {:ok, {<<>>, file}}
  def split(file, at), do: {:ok, split!(file, at)}

  def split!(file, at) do
    {
      Slice.wrap(file, 0, at),
      Slice.wrap(file, at, nil)
    }
  end

  def starts_with?(_, <<>>), do: true

  def starts_with?(file, prefix) do
    case to_binary(file, 0, byte_size(prefix)) do
      {:ok, data} -> data == prefix
      {:error, _} -> false
    end
  end

  def to_iodata(file), do: to_binary(file)
  def to_iodata!(file), do: to_binary!(file)

  def to_iodata(file, start, count), do: to_binary(file, start, count)
  def to_iodata!(file, start, count), do: to_binary!(file, start, count)

  def to_binary(file) when file.count == 0, do: {:ok, <<>>}

  def to_binary(file) do
    case :file.pread(file, {:bof, 0}, size(file)) do
      {:ok, data} -> {:ok, data}
      :eof -> {:error, :eof}
      {:error, reason} -> {:error, reason}
    end
  end

  def to_binary!(file) do
    case to_binary(file) do
      {:ok, data} -> data
      {:error, reason} -> raise ArgumentError, message: "#{reason}"
    end
  end

  def to_binary(_, _, 0), do: {:ok, <<>>}

  def to_binary(file, start, count) do
    case :file.pread(file, {:bof, start}, count) do
      {:ok, data} -> {:ok, data}
      :eof -> {:error, :eof}
      {:error, reason} -> {:error, reason}
    end
  end

  def to_binary!(file, start, count) do
    case to_binary(file, start, count) do
      {:ok, data} -> data
      {:error, reason} -> raise ArgumentError, message: "#{reason}"
    end
  end
end
