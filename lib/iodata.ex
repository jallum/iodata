defprotocol IOData do
  @moduledoc """
  A protocol for working with various data types such as binaries and iolists.

  This protocol defines a set of functions for performing common operations on
  data, including:

  - Checking if the data has at least a specified number of bytes.
  - Retrieving the size of the data in bytes.
  - Splitting the data at a specified byte offset.
  - Checking if the data starts with a given binary prefix.
  - Converting the data to iodata or binary formats.
  - Extracting portions of the data as iodata or binary.

  Implementations of this protocol should be efficient and avoid unnecessary
  copying of data whenever possible.
  """

  @type t :: term()

  @doc "Checks if the given data has at least the specified number of bytes."
  @spec at_least?(t(), n_bytes :: non_neg_integer()) :: boolean()
  def at_least?(data, n_bytes)

  @doc "Returns the total size, in bytes, of the given data."
  @spec size(t()) :: non_neg_integer()
  def size(data)

  @doc "Splits data at the specified byte offset if possible, returning either {:ok, {prefix, suffix}} or an error tuple."
  @spec split(t(), non_neg_integer()) :: {:ok, {t(), t()}} | {:error, :insufficient_data}
  def split(data, at)

  @doc "Checks if the given data starts with the specified binary prefix."
  @spec starts_with?(t(), binary()) :: boolean()
  def starts_with?(data, binary)

  @doc "Returns the data in iodata form without modifying it."
  @spec to_iodata(t()) :: iodata()
  def to_iodata(data)

  @doc "Extracts a portion of the data as iodata, starting at 'start' for 'count' bytes. Returns an ok/error tuple."
  @spec to_iodata(t(), start :: non_neg_integer(), count :: non_neg_integer()) ::
          {:ok, t()} | {:error, :insufficient_data}
  def to_iodata(data, start, count)

  @doc "Same as to_iodata/3 but raises an error if the data is insufficient."
  @spec to_iodata!(t(), start :: non_neg_integer(), count :: non_neg_integer()) :: iodata()
  def to_iodata!(data, start, count)

  @doc "Converts the entire data into a binary."
  @spec to_binary(t()) :: binary()
  def to_binary(data)

  @doc "Extracts a portion of the data as a binary, starting at 'start' for 'count' bytes. Returns an ok/error tuple."
  @spec to_binary(t(), start :: non_neg_integer(), count :: non_neg_integer()) ::
          {:ok, binary()} | {:error, :insufficient_data}
  def to_binary(data, start, count)

  @doc "Same as to_binary/3 but raises an error if the data is insufficient."
  @spec to_binary!(t(), start :: non_neg_integer(), count :: non_neg_integer()) :: binary()
  def to_binary!(data, start, count)
end
