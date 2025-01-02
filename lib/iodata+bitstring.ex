defimpl IOData, for: BitString do
  @moduledoc """
  Implementation of the `IOData` protocol for `BitString`.

  This module provides various functions to manipulate and query binaries, such
  as checking their size, splitting them, etc. without having to create copies.
  """

  def at_least?(_data, 0), do: true
  def at_least?(data, bytes), do: bytes <= byte_size(data)

  def size(data), do: byte_size(data)

  def split(data, 0), do: {:ok, {<<>>, data}}
  def split(data, at) when at <= byte_size(data), do: {:ok, :erlang.split_binary(data, at)}
  def split(_, _), do: {:error, :insufficient_data}

  def split!(data, at) do
    case split(data, at) do
      {:ok, {a, b}} -> {a, b}
      {:error, reason} -> raise ArgumentError, message: "#{reason}"
    end
  end

  def starts_with?(data, value),
    do: :binary.longest_common_prefix([data, value]) == byte_size(value)

  def to_iodata(data), do: {:ok, data}

  def to_iodata(data, start, count) when byte_size(data) < count + start,
    do: {:error, :insufficient_data}

  def to_iodata(data, start, count), do: to_binary(data, start, count)

  def to_iodata!(data), do: data

  def to_iodata!(data, start, count) do
    case to_iodata(data, start, count) do
      {:ok, iodata} -> iodata
      {:error, reason} -> raise ArgumentError, message: "#{reason}"
    end
  end

  def to_binary(data), do: {:ok, data}

  def to_binary(data, start, nil), do: {:ok, binary_part(data, start, byte_size(data) - start)}

  def to_binary(data, start, count) when byte_size(data) < count + start,
    do: {:error, :insufficient_data}

  def to_binary(data, start, count), do: {:ok, binary_part(data, start, count)}

  def to_binary!(data), do: data

  def to_binary!(data, start, count) do
    case to_binary(data, start, count) do
      {:ok, binary} -> binary
      {:error, reason} -> raise ArgumentError, message: "#{reason}"
    end
  end
end
