defimpl IOData, for: PID do
  @moduledoc """
  Implementation of the `IOData` protocol for files opened without `:raw`
  (`File.open/2`, `:file.open/2`). See `IOData.File`.
  """

  alias IOData.File

  def at_least?(file, n_bytes), do: File.at_least?(file, n_bytes)
  def size(file), do: File.size(file)

  def slice(file, {start, count}), do: File.slice(file, start, count)
  def slice(file, start, count), do: File.slice(file, start, count)
  def slice!(file, {start, count}), do: File.slice!(file, start, count)
  def slice!(file, start, count), do: File.slice!(file, start, count)

  def split(file, 0), do: {:ok, {<<>>, file}}
  def split(file, at), do: File.split(file, at)
  def split!(file, at), do: File.split!(file, at)

  def starts_with?(file, prefix), do: File.starts_with?(file, prefix)

  def to_iodata(file), do: File.to_binary(file)
  def to_iodata!(file), do: File.to_binary!(file)
  def to_iodata(file, start, count), do: File.to_binary(file, start, count)
  def to_iodata!(file, start, count), do: File.to_binary!(file, start, count)

  def to_binary(file), do: File.to_binary(file)
  def to_binary!(file), do: File.to_binary!(file)
  def to_binary(file, start, count), do: File.to_binary(file, start, count)
  def to_binary!(file, start, count), do: File.to_binary!(file, start, count)
end

defimpl IOData, for: Tuple do
  @moduledoc """
  Implementation of the `IOData` protocol for `:raw` file handles — the
  `{:file_descriptor, _, _}` tuples returned by `:file.open(path, [:raw, ...])`.
  See `IOData.File`.

  Any other tuple raises `Protocol.UndefinedError`.
  """

  alias IOData.File

  defp fd({:file_descriptor, _, _} = fd), do: fd

  defp fd(other) do
    raise Protocol.UndefinedError,
      protocol: IOData,
      value: other,
      description: "only raw file handles ({:file_descriptor, _, _}) are supported"
  end

  def at_least?(file, n_bytes), do: File.at_least?(fd(file), n_bytes)
  def size(file), do: File.size(fd(file))

  def slice(file, {start, count}), do: File.slice(fd(file), start, count)
  def slice(file, start, count), do: File.slice(fd(file), start, count)
  def slice!(file, {start, count}), do: File.slice!(fd(file), start, count)
  def slice!(file, start, count), do: File.slice!(fd(file), start, count)

  def split(file, 0), do: {:ok, {<<>>, fd(file)}}
  def split(file, at), do: File.split(fd(file), at)
  def split!(file, at), do: File.split!(fd(file), at)

  def starts_with?(file, prefix), do: File.starts_with?(fd(file), prefix)

  def to_iodata(file), do: File.to_binary(fd(file))
  def to_iodata!(file), do: File.to_binary!(fd(file))
  def to_iodata(file, start, count), do: File.to_binary(fd(file), start, count)
  def to_iodata!(file, start, count), do: File.to_binary!(fd(file), start, count)

  def to_binary(file), do: File.to_binary(fd(file))
  def to_binary!(file), do: File.to_binary!(fd(file))
  def to_binary(file, start, count), do: File.to_binary(fd(file), start, count)
  def to_binary!(file, start, count), do: File.to_binary!(fd(file), start, count)
end
