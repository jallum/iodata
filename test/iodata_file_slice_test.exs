defmodule IODataFileSliceTest do
  use ExUnit.Case, async: false
  use ExUnitProperties

  alias File.Slice

  defp tmp_file(data) do
    file_name = Path.join(["file_slice_test_#{:rand.uniform(100_000)}"])
    :ok = File.write(file_name, data)
    {:ok, fd} = :file.open(file_name |> String.to_charlist(), [:read, :binary])
    File.rm(file_name)
    on_exit(fn -> :file.close(fd) end)
    fd
  end

  property "at_least?/2 returns true if slice size is at least n_bytes" do
    check all(
            size <- positive_integer(),
            n_bytes <- integer(0..size)
          ) do
      slice = %Slice{file: nil, start: 0, count: size}
      assert IOData.at_least?(slice, n_bytes)
    end
  end

  property "size/1 returns the correct size of the slice" do
    check all(size <- positive_integer()) do
      slice = %Slice{file: nil, start: 0, count: size}
      assert IOData.size(slice) == size
    end
  end

  property "split/2 splits the slice correctly" do
    check all(
            size <- positive_integer(),
            at <- integer(0..size)
          ) do
      slice = %Slice{file: nil, start: 0, count: size}

      case IOData.split(slice, at) do
        {:ok, {<<>>, %Slice{count: count}}} when at == 0 ->
          assert count == size

        {:ok, {%Slice{count: count1}, %Slice{count: count2}}} ->
          assert count1 == at
          assert count2 == size - at

        {:error, :insufficient_data} ->
          assert at > size
      end
    end
  end

  property "starts_with?/2 returns true if slice starts with prefix" do
    check all(
            data_len <- integer(0..100),
            data <- binary(min_length: data_len),
            prefix_len <- integer(0..data_len)
          ) do
      slice = Slice.wrap(tmp_file(data), data_len)

      prefix = binary_part(data, 0, prefix_len)
      assert IOData.starts_with?(slice, prefix)
    end
  end

  property "to_binary/1 reads the correct binary data from the slice" do
    check all(data <- binary()) do
      slice = Slice.wrap(tmp_file(data), byte_size(data))

      assert {:ok, ^data} = IOData.to_binary(slice)
    end
  end

  property "to_binary/3 reads the correct binary data from the slice" do
    check all(
            data_len <- integer(0..100),
            data <- binary(min_length: data_len),
            start <- integer(0..data_len),
            count <- integer(0..(data_len - start))
          ) do
      slice = File.Slice.wrap(tmp_file(data), data_len)

      {:ok, expected_data} = IOData.to_binary(slice, start, count)
      assert expected_data == binary_part(data, start, count)
    end
  end
end
