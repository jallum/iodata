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

  defp closed_file do
    file_name = "file_file_test_closed_#{:rand.uniform(100_000)}"
    {:ok, file} = File.open(file_name, [:write, :read, :binary])
    :ok = File.rm(file_name)
    :ok = File.close(file)
    file
  end

  test "size/1 returns false when the file cannot be read" do
    assert IOData.size(closed_file()) == false
  end

  test "slice/2 wraps the file in a slice" do
    file = tmp_file("hello world")
    assert IOData.slice(file, {6, 5}) == {:ok, IOData.Slice.wrap(file, 6, 5)}
  end

  test "slice/3 wraps the file in a slice" do
    file = tmp_file("hello world")
    assert IOData.slice(file, 6, 5) == {:ok, IOData.Slice.wrap(file, 6, 5)}
  end

  test "slice!/2 wraps the file in a slice" do
    file = tmp_file("hello world")
    assert IOData.slice!(file, {0, 5}) == IOData.Slice.wrap(file, 0, 5)
  end

  test "slice!/3 wraps the file in a slice" do
    file = tmp_file("hello world")
    assert IOData.slice!(file, 0, 5) == IOData.Slice.wrap(file, 0, 5)
  end

  test "split/2 at zero returns an empty prefix and the file itself" do
    file = tmp_file("hello")
    assert IOData.split(file, 0) == {:ok, {<<>>, file}}
  end

  test "starts_with?/2 is true for an empty prefix" do
    file = tmp_file("hello")
    assert IOData.starts_with?(file, <<>>)
  end

  test "starts_with?/2 is false when the prefix is longer than the file" do
    file = tmp_file("hi")
    refute IOData.starts_with?(file, "hi there")
  end

  test "starts_with?/2 is false when the file is empty and the prefix is not" do
    file = tmp_file(<<>>)
    refute IOData.starts_with?(file, "x")
  end

  test "to_iodata/1 reads the whole file" do
    file = tmp_file("hello")
    assert IOData.to_iodata(file) == {:ok, "hello"}
  end

  test "to_iodata!/1 reads the whole file" do
    file = tmp_file("hello")
    assert IOData.to_iodata!(file) == "hello"
  end

  test "to_iodata/3 reads the requested range" do
    file = tmp_file("hello world")
    assert IOData.to_iodata(file, 6, 5) == {:ok, "world"}
  end

  test "to_iodata!/3 reads the requested range" do
    file = tmp_file("hello world")
    assert IOData.to_iodata!(file, 6, 5) == "world"
  end

  test "to_binary/3 with a zero count returns an empty binary" do
    file = tmp_file("hello")
    assert IOData.to_binary(file, 0, 0) == {:ok, <<>>}
  end

  test "to_binary/3 returns an eof error when reading past the end" do
    file = tmp_file("hello")
    assert IOData.to_binary(file, 100, 5) == {:error, :eof}
  end

  test "to_binary!/3 raises when reading past the end" do
    file = tmp_file("hello")
    assert_raise ArgumentError, fn -> IOData.to_binary!(file, 100, 5) end
  end

  test "to_binary/1 returns an error when the file cannot be read" do
    assert {:error, _} = IOData.to_binary(closed_file())
  end

  test "to_binary!/1 raises when the file cannot be read" do
    assert_raise ArgumentError, fn -> IOData.to_binary!(closed_file()) end
  end

  test "to_binary/3 returns an error when the file is closed" do
    assert {:error, :terminated} = IOData.to_binary(closed_file(), 0, 3)
  end
end
