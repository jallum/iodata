defmodule Arrow.IODataBitstringTest do
  use ExUnit.Case
  use ExUnitProperties

  property "at_least?/2" do
    check all(
            data <- binary(),
            bytes <- integer(0..byte_size(data))
          ) do
      assert IOData.at_least?(data, bytes) == bytes <= byte_size(data)
    end
  end

  property "starts_with?/2" do
    check all(
            data <- binary(),
            prefix <- binary()
          ) do
      assert IOData.starts_with?(data, prefix) ==
               (:binary.longest_common_prefix([data, prefix]) == byte_size(prefix))
    end
  end

  property "split/2" do
    check all(
            data <- binary(),
            at <- integer(0..byte_size(data))
          ) do
      case IOData.split(data, at) do
        {:ok, {a, b}} -> assert a <> b == data
        {:error, :insufficient_data} -> assert at > byte_size(data)
      end
    end
  end

  property "to_iodata/1" do
    check all(data <- binary()) do
      assert IOData.to_iodata(data) == {:ok, data}
    end
  end

  property "to_iodata!/1" do
    check all(data <- binary()) do
      assert IOData.to_iodata!(data) == data
    end
  end

  property "to_iodata/3" do
    check all(
            data <- binary(),
            start <- integer(0..byte_size(data)),
            count <- integer(0..(byte_size(data) - start))
          ) do
      case IOData.to_iodata(data, start, count) do
        {:ok, iodata} -> assert iodata == binary_part(data, start, count)
        {:error, :insufficient_data} -> assert byte_size(data) < count + start
      end
    end
  end

  property "to_binary/1" do
    check all(data <- binary()) do
      assert IOData.to_binary(data) == {:ok, data}
    end
  end

  property "to_binary!/1" do
    check all(data <- binary()) do
      assert IOData.to_binary!(data) == data
    end
  end

  property "to_binary/3" do
    check all(
            data <- binary(),
            start <- integer(0..byte_size(data)),
            count <- integer(0..(byte_size(data) - start))
          ) do
      case IOData.to_binary(data, start, count) do
        {:ok, binary} -> assert binary == binary_part(data, start, count)
        {:error, :insufficient_data} -> assert byte_size(data) < count + start
      end
    end
  end

  test "size/1 returns the byte size of the binary" do
    assert IOData.size(<<>>) == 0
    assert IOData.size("hello") == 5
  end

  test "slice/2 extracts the requested range as a binary" do
    assert IOData.slice("hello world", {6, 5}) == {:ok, "world"}
  end

  test "slice/3 extracts the requested range as a binary" do
    assert IOData.slice("hello world", 0, 5) == {:ok, "hello"}
  end

  test "slice returns an error when the range extends past the end" do
    assert IOData.slice("abc", {2, 5}) == {:error, :insufficient_data}
    assert IOData.slice("abc", 2, 5) == {:error, :insufficient_data}
  end

  test "slice!/2 returns the slice directly" do
    assert IOData.slice!("hello world", {6, 5}) == "world"
  end

  test "slice!/2 raises when the range extends past the end" do
    assert_raise ArgumentError, fn -> IOData.slice!("abc", {0, 10}) end
  end

  test "slice!/3 returns the slice directly" do
    assert IOData.slice!("hello world", 0, 5) == "hello"
  end

  test "slice!/3 raises when the range extends past the end" do
    assert_raise ArgumentError, fn -> IOData.slice!("abc", 1, 10) end
  end

  test "split/2 returns an error when splitting past the end" do
    assert IOData.split("abc", 4) == {:error, :insufficient_data}
  end

  test "split!/2 splits the binary in two" do
    assert IOData.split!("hello world", 5) == {"hello", " world"}
  end

  test "split!/2 raises when splitting past the end" do
    assert_raise ArgumentError, fn -> IOData.split!("abc", 4) end
  end

  test "to_iodata/3 returns an error when the range extends past the end" do
    assert IOData.to_iodata("abc", 1, 5) == {:error, :insufficient_data}
  end

  test "to_iodata!/3 extracts the requested range" do
    assert IOData.to_iodata!("hello world", 6, 5) == "world"
  end

  test "to_iodata!/3 raises when the range extends past the end" do
    assert_raise ArgumentError, fn -> IOData.to_iodata!("abc", 1, 5) end
  end

  test "to_binary/3 with a nil count reads to the end of the binary" do
    assert IOData.to_binary("hello world", 6, nil) == {:ok, "world"}
  end

  test "to_binary!/3 extracts the requested range" do
    assert IOData.to_binary!("hello world", 0, 5) == "hello"
  end

  test "to_binary!/3 raises when the range extends past the end" do
    assert_raise ArgumentError, fn -> IOData.to_binary!("abc", 2, 5) end
  end
end
