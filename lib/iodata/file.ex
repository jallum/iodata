defmodule IOData.File do
  @moduledoc """
  A structure that represents a file and can be used with IOData. A `File` can
  be opened or wrapped around an existing file-descriptor or reference.

  ## Examples

      iex> {:ok, slice} = IOData.File.open("path/to/file")
      iex> IOData.to_binary(slice)
      {:ok, <<0, 1, 2, 3, 4, 5, 6, 7, 8, 9>>}

      iex> {head, tail} = IOData.split!(slice, 5)
      iex> IOData.to_binary(tail)
      {:ok, <<5, 6, 7, 8, 9>>}
  """

  @type t :: %__MODULE__{
          file: pid() | reference(),
          start: non_neg_integer(),
          count: non_neg_integer()
        }
  defstruct [:file, :start, :count]

  @doc """
  Opens a file and returns a slice that can be used with IOData. The slice
  represents the entire file.
  """
  @spec open(path :: String.t()) :: {:ok, t()} | {:error, term()}
  def open(path) do
    case File.open(path, [:read, :binary]) do
      {:ok, file} -> {:ok, %__MODULE__{file: file, start: 0, count: File.stat!(path).size}}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Opens a file and returns a slice that can be used with IOData. The slice
  represents the entire file. If the file cannot be opened, an exception is
  raised.
  """
  @spec open!(path :: String.t()) :: t()
  def open!(path) do
    case open(path) do
      {:ok, slice} -> slice
      {:error, reason} -> raise "Failed to open file: #{inspect(reason)}"
    end
  end

  @doc """
  Wraps an existing file or reference in a slice that can be used with IOData. A
  length is required in order to provide boundary checking.
  """
  @spec wrap(
          file :: pid() | reference(),
          start :: non_neg_integer(),
          count :: non_neg_integer()
        ) ::
          t()
  def wrap(file, start \\ 0, count) when is_pid(file) or is_reference(file),
    do: %__MODULE__{file: file, start: start, count: count}
end
