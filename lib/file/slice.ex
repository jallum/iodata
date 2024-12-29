defmodule File.Slice do
  defstruct [:file, :start, :count]

  @doc """
  Wraps a file or reference in a slice that can be used with IOData
  """
  def wrap(file, start \\ 0, count) when is_pid(file) or is_reference(file),
    do: %File.Slice{file: file, start: start, count: count}
end
