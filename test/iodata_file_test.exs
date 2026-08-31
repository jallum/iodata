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

  test "size/1 raises when the file cannot be read" do
    assert_raise ArgumentError, ~r/cannot read file size/, fn -> IOData.size(closed_file()) end
  end

  test "at_least?/2 is false when the file cannot be read" do
    refute IOData.at_least?(closed_file(), 0)
    refute IOData.at_least?(closed_file(), 1)
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

  test "the suffix of split/2 (a slice with no count) reads to the end of the file" do
    file = tmp_file("hello world")
    {_, suffix} = IOData.split!(file, 6)
    assert IOData.to_binary(suffix) == {:ok, "world"}
    assert IOData.to_binary(IOData.Slice.wrap(file, 11)) == {:ok, <<>>}
    assert IOData.to_binary(IOData.Slice.wrap(file, 20)) == {:ok, <<>>}
    assert {:error, _} = IOData.to_binary(IOData.Slice.wrap(closed_file(), 1))
  end

  test "to_binary/3 with a zero count returns an empty binary" do
    file = tmp_file("hello")
    assert IOData.to_binary(file, 0, 0) == {:ok, <<>>}
  end

  test "to_binary/3 returns an error when reading past the end" do
    file = tmp_file("hello")
    assert IOData.to_binary(file, 100, 5) == {:error, :insufficient_data}
  end

  test "to_binary/3 returns an error instead of a short read when the range overlaps the end" do
    file = tmp_file("hello")
    assert IOData.to_binary(file, 3, 5) == {:error, :insufficient_data}
    assert IOData.to_binary(file, 0, 6) == {:error, :insufficient_data}
    assert IOData.to_binary(file, 3, 2) == {:ok, "lo"}
  end

  test "text-mode files still yield binaries" do
    file_name = "file_file_test_text_#{:rand.uniform(100_000)}"
    {:ok, file} = :file.open(file_name, [:write, :read])
    :ok = File.rm(file_name)
    :ok = :file.pwrite(file, 0, "hello")
    on_exit(fn -> :file.close(file) end)

    assert IOData.to_binary(file) == {:ok, "hello"}
    assert IOData.to_binary(file, 1, 3) == {:ok, "ell"}
    assert IOData.starts_with?(file, "he")
  end

  test "split/2 validates the offset against the file size" do
    file = tmp_file("hello")
    assert IOData.split(file, 6) == {:error, :insufficient_data}
    assert_raise ArgumentError, fn -> IOData.split!(file, 6) end
    assert {:ok, {prefix, suffix}} = IOData.split(file, 5)
    assert IOData.to_binary(prefix) == {:ok, "hello"}
    assert IOData.to_binary(suffix) == {:ok, <<>>}
    assert {:error, _} = IOData.split(closed_file(), 1)
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

  describe "raw files" do
    defp raw_file(data) do
      file_name = Path.join(["file_file_test_raw_#{:rand.uniform(100_000)}"])
      {:ok, file} = :file.open(file_name, [:write, :read, :binary, :raw])
      :ok = File.rm(file_name)
      :ok = :file.pwrite(file, 0, data)
      # No on_exit close: a raw handle is owned by this process and goes away
      # with it; on_exit callbacks run elsewhere.
      file
    end

    test "are {:file_descriptor, _, _} tuples" do
      assert {:file_descriptor, _, _} = raw_file("x")
    end

    test "size/1 and at_least?/2" do
      file = raw_file("hello world")
      assert IOData.size(file) == 11
      assert IOData.at_least?(file, 11)
      refute IOData.at_least?(file, 12)
    end

    test "split/2 and slice/3 are lazy" do
      file = raw_file("hello world")
      assert IOData.split(file, 0) == {:ok, {<<>>, file}}
      assert {:ok, {a, b}} = IOData.split(file, 5)
      assert IOData.to_binary(a) == {:ok, "hello"}
      assert IOData.to_binary(b) == {:ok, " world"}
      assert IOData.slice!(file, 6, 5) |> IOData.to_binary!() == "world"
      assert IOData.slice!(file, {6, 5}) |> IOData.to_binary!() == "world"
      assert {:ok, %IOData.Slice{}} = IOData.slice(file, 6, 5)
      assert {:ok, %IOData.Slice{}} = IOData.slice(file, {6, 5})
      assert {%IOData.Slice{}, %IOData.Slice{}} = IOData.split!(file, 3)
    end

    test "starts_with?/2" do
      file = raw_file("hello world")
      assert IOData.starts_with?(file, "hello")
      refute IOData.starts_with?(file, "world")
    end

    test "to_binary and to_iodata read the file" do
      file = raw_file("hello world")
      assert IOData.to_binary(file) == {:ok, "hello world"}
      assert IOData.to_binary!(file) == "hello world"
      assert IOData.to_iodata(file) == {:ok, "hello world"}
      assert IOData.to_iodata!(file) == "hello world"
      assert IOData.to_binary(file, 6, 5) == {:ok, "world"}
      assert IOData.to_binary!(file, 6, 5) == "world"
      assert IOData.to_iodata(file, 6, 5) == {:ok, "world"}
      assert IOData.to_iodata!(file, 6, 5) == "world"
      assert IOData.to_binary(file, 100, 5) == {:error, :insufficient_data}
      assert IOData.to_binary(file, 9, 5) == {:error, :insufficient_data}
    end

    test "text-mode raw files still yield binaries" do
      file_name = "file_file_test_rawtext_#{:rand.uniform(100_000)}"
      {:ok, file} = :file.open(file_name, [:write, :read, :raw])
      :ok = File.rm(file_name)
      :ok = :file.pwrite(file, 0, "hello")
      assert IOData.to_binary(file) == {:ok, "hello"}
      assert IOData.starts_with?(file, "he")
    end

    test "split/2 validates the offset against the file size" do
      file = raw_file("hello")
      assert IOData.split(file, 6) == {:error, :insufficient_data}
      assert_raise ArgumentError, fn -> IOData.split!(file, 6) end
    end

    test "other tuples raise Protocol.UndefinedError" do
      assert_raise Protocol.UndefinedError, ~r/only raw file handles/, fn ->
        IOData.size({:ok, "nope"})
      end

      assert_raise Protocol.UndefinedError, fn -> IOData.split({1, 2}, 0) end
      assert_raise Protocol.UndefinedError, fn -> IOData.to_binary({}) end
    end
  end
end
