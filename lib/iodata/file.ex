defmodule IOData.File do
  @moduledoc """
  Shared implementation of the `IOData` protocol for open files.

  Backs both file-handle impls of `IOData`:

    * `PID` — a file opened without `:raw`, served by the file server.
    * `Tuple` — the `{:file_descriptor, _, _}` handle that `:file.open/2` returns
      for `:raw` files.

  Raw handles skip the file-server hop, so every read is roughly 5x cheaper,
  but they can only be used from the process that opened them.

  Every operation here is at least one round trip to the file. `split/2` and
  `slice/2,3` are lazy — they return `IOData.Slice`s and do no I/O.
  """

  alias IOData.Slice

  def at_least?(file, n_bytes) do
    case :file.read_file_info(file) do
      {:ok, info} -> elem(info, 1) >= n_bytes
      {:error, _} -> false
    end
  end

  def size(file) do
    case :file.read_file_info(file) do
      {:ok, info} -> elem(info, 1)
      {:error, reason} -> raise ArgumentError, "cannot read file size: #{inspect(reason)}"
    end
  end

  def slice(file, start, count), do: {:ok, Slice.wrap(file, start, count)}
  def slice!(file, start, count), do: Slice.wrap(file, start, count)

  def split(file, at), do: {:ok, split!(file, at)}

  def split!(file, at), do: {Slice.wrap(file, 0, at), Slice.wrap(file, at, nil)}

  def starts_with?(_file, <<>>), do: true

  def starts_with?(file, prefix) do
    case to_binary(file, 0, byte_size(prefix)) do
      {:ok, data} -> data == prefix
      {:error, _} -> false
    end
  end

  def to_binary(file) do
    case :file.read_file_info(file) do
      {:ok, info} -> to_binary(file, 0, elem(info, 1))
      {:error, reason} -> {:error, reason}
    end
  end

  def to_binary!(file) do
    case to_binary(file) do
      {:ok, data} -> data
      {:error, reason} -> raise ArgumentError, message: "#{reason}"
    end
  end

  def to_binary(_file, _start, 0), do: {:ok, <<>>}

  def to_binary(file, start, nil) do
    case :file.read_file_info(file) do
      {:ok, info} -> to_binary(file, start, max(elem(info, 1) - start, 0))
      {:error, reason} -> {:error, reason}
    end
  end

  def to_binary(file, start, count) do
    # An integer offset works for both handle kinds; `{:bof, n}` is file-server only.
    case :file.pread(file, start, count) do
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
