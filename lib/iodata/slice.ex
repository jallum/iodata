defmodule IOData.Slice do
  @moduledoc """
  A module for handling slices of IO data.

  This module provides a way to work with slices of IO data, allowing you to
  wrap a portion of IO data and perform operations such as checking the size,
  splitting, and converting to binary or IO data.

  ## Types

    * `t/0` - The type representing a slice of IO data.

  ## Functions

    * `wrap/3` - Wraps a portion of IO data into a slice.

  ## Examples

      iex> slice = IOData.Slice.wrap("hello world", 0, 5)
      %IOData.Slice{iodata: "hello world", start: 0, count: 5}

      iex> IOData.at_least?(slice, 3)
      true

      iex> IOData.split(slice, 2)
      {:ok, {%IOData.Slice{iodata: "hello world", start: 0, count: 2}, %IOData.Slice{iodata: "hello world", start: 2, count: 3}}}

      iex> IOData.to_binary(slice)
      {:ok, "hello"}
  """

  @type t :: %__MODULE__{
          iodata: IOData.t(),
          start: non_neg_integer(),
          count: non_neg_integer() | nil
        }
  defstruct [:iodata, :start, :count]

  @doc """
  Wraps a portion of IO data into a slice.

  ## Parameters

    * `iodata` - The IO data to wrap.
    * `start` - The starting position of the slice.
    * `count` - The number of bytes in the slice (optional).

  ## Examples

      iex> IOData.Slice.wrap("hello world", 0, 5)
      %IOData.Slice{iodata: "hello world", start: 0, count: 5}
  """
  def wrap(iodata, start, count \\ nil)

  def wrap(%__MODULE__{iodata: iodata}, start, count) do
    %__MODULE__{iodata: iodata, start: start, count: count}
  end

  def wrap(iodata, start, count) do
    %__MODULE__{iodata: iodata, start: start, count: count}
  end
end
