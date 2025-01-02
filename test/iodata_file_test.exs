defmodule IODataFileTest do
  use ExUnit.Case, async: false
  use ExUnitProperties

  defp tmp_file(data) do
    file_name = Path.join(["file_file_test_#{:rand.uniform(100_000)}"])
    {:ok, file} = File.open(file_name, [:write, :read, :binary])
    :ok = File.rm(file_name)
    :ok = :file.pwrite(file, 0, data)

    on_exit(fn ->
      :ok = File.close(file)
    end)

    file
  end

  property "at_least?/2 returns true if file size is at least n_bytes" do
    check all(
            size <- integer(0..10_000),
            data <- binary(length: size),
            n_bytes <- integer(0..size)
          ) do
      file = tmp_file(data)
      assert IOData.at_least?(file, n_bytes)
    end
  end

  property "size/1 returns the correct size of the file" do
    check all(
            size <- integer(0..10_000),
            data <- binary(length: size)
          ) do
      file = tmp_file(data)
      assert IOData.size(file) == size
    end
  end

  property "split/2 splits the file correctly" do
    check all(
            size <- integer(0..10_000),
            data <- binary(length: size),
            at <- integer(0..size)
          ) do
      file = tmp_file(data)

      case IOData.split(file, at) do
        {:ok, {<<>>, ^file}} when at == 0 ->
          :ok

        {:ok, {%IOData.Slice{count: count1}, %IOData.Slice{count: nil}}} ->
          assert count1 == at

        {:error, :insufficient_data} ->
          assert at > size
      end
    end
  end

  property "starts_with?/2 returns true if file starts with prefix" do
    check all(
            data_len <- integer(0..10_000),
            data <- binary(length: data_len),
            prefix_len <- integer(0..data_len)
          ) do
      file = tmp_file(data)

      prefix = binary_part(data, 0, prefix_len)
      assert IOData.starts_with?(file, prefix)
    end
  end

  property "to_binary/1 reads the correct binary data from the file" do
    check all(
            data_len <- integer(0..10_000),
            data <- binary(length: data_len)
          ) do
      file = tmp_file(data)

      assert {:ok, ^data} = IOData.to_binary(file)
    end
  end

  property "to_binary/3 reads the correct binary data from the file" do
    check all(
            data_len <- integer(0..10_000),
            data <- binary(length: data_len),
            start <- integer(0..data_len),
            count <- integer(0..(data_len - start))
          ) do
      file = tmp_file(data)

      {:ok, expected_data} = IOData.to_binary(file, start, count)
      assert expected_data == binary_part(data, start, count)
    end
  end
end
