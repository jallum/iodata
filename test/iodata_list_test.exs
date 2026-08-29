defmodule IOIODataListTest do
  use ExUnit.Case
  use ExUnitProperties

  property "at_least?/2" do
    check all(
            data <- iolist(),
            bytes <- integer(0..IO.iodata_length(data))
          ) do
      assert IOData.at_least?(data, bytes) == bytes <= IO.iodata_length(data)
    end
  end

  property "starts_with?/2" do
    check all(
            data <- iolist(),
            prefix <- binary()
          ) do
      assert IOData.starts_with?(data, prefix) ==
               (:binary.longest_common_prefix([IO.iodata_to_binary(data), prefix]) ==
                  byte_size(prefix))
    end
  end

  property "split/2" do
    check all(
            data <- iolist(),
            at <- integer(0..IO.iodata_length(data))
          ) do
      case IOData.split(data, at) do
        {:ok, {a, b}} ->
          assert IO.iodata_to_binary(a) <> IO.iodata_to_binary(b) == IO.iodata_to_binary(data)

        {:error, :insufficient_data} ->
          assert at > IO.iodata_length(data)
      end
    end
  end

  property "to_iodata/1" do
    check all(data <- iolist()) do
      assert IOData.to_iodata(data) == {:ok, data}
    end
  end

  property "to_iodata!/1" do
    check all(data <- iolist()) do
      assert IOData.to_iodata!(data) == data
    end
  end

  property "to_iodata/3" do
    check all(
            data <- iolist(),
            start <- integer(0..IO.iodata_length(data)),
            count <- integer(0..(IO.iodata_length(data) - start))
          ) do
      case IOData.to_iodata(data, start, count) do
        {:ok, iodata} ->
          assert IO.iodata_to_binary(iodata) ==
                   binary_part(IO.iodata_to_binary(data), start, count)

        {:error, :insufficient_data} ->
          assert IO.iodata_length(data) < count + start
      end
    end
  end

  property "to_binary/1" do
    check all(data <- iolist()) do
      assert IOData.to_binary(data) == {:ok, IO.iodata_to_binary(data)}
    end
  end

  property "to_binary!/1" do
    check all(data <- iolist()) do
      assert IOData.to_binary!(data) == IO.iodata_to_binary(data)
    end
  end

  property "to_binary/3" do
    check all(
            data <- iolist(),
            start <- integer(0..IO.iodata_length(data)),
            count <- integer(0..(IO.iodata_length(data) - start))
          ) do
      case IOData.to_binary(data, start, count) do
        {:ok, binary} -> assert binary == binary_part(IO.iodata_to_binary(data), start, count)
        {:error, :insufficient_data} -> assert IO.iodata_length(data) < count + start
      end
    end
  end

  test "at_least?/2 is false for an empty list and a positive byte count" do
    refute IOData.at_least?([], 1)
    assert IOData.at_least?([], 0)
  end

  test "size/1 returns 0 for an empty list" do
    assert IOData.size([]) == 0
  end

  test "size/1 returns the total byte size of a nested iolist" do
    assert IOData.size(["he", [?l, ["lo"]]]) == 5
  end

  test "slice/2 extracts the requested range" do
    {:ok, slice} = IOData.slice(["he", "llo"], {1, 3})
    assert IO.iodata_to_binary(slice) == "ell"
  end

  test "slice/3 extracts the requested range" do
    {:ok, slice} = IOData.slice(["he", "llo"], 1, 3)
    assert IO.iodata_to_binary(slice) == "ell"
  end

  test "slice!/2 returns the slice directly" do
    assert IO.iodata_to_binary(IOData.slice!(["he", "llo"], {0, 4})) == "hell"
  end

  test "slice!/2 raises when the range extends past the end" do
    assert_raise ArgumentError, fn -> IOData.slice!(["ab"], {1, 5}) end
  end

  test "slice!/3 returns the slice directly" do
    assert IO.iodata_to_binary(IOData.slice!(["he", "llo"], 2, 3)) == "llo"
  end

  test "slice!/3 raises when the range extends past the end" do
    assert_raise ArgumentError, fn -> IOData.slice!(["ab"], 5, 1) end
  end

  test "split/2 of an empty list at a positive offset returns an error" do
    assert IOData.split([], 2) == {:error, :insufficient_data}
  end

  test "split/2 returns an error when splitting past the end" do
    assert IOData.split(["ab"], 3) == {:error, :insufficient_data}
    assert IOData.split(["ab", "cd"], 5) == {:error, :insufficient_data}
    assert IOData.split([?a, ?b], 3) == {:error, :insufficient_data}
  end

  test "split/2 returns an error when only nested empty lists remain" do
    assert IOData.split([[], [<<>>]], 1) == {:error, :insufficient_data}
  end

  test "split!/2 splits the iolist in two" do
    {prefix, suffix} = IOData.split!(["he", "llo"], 3)
    assert IO.iodata_to_binary(prefix) == "hel"
    assert IO.iodata_to_binary(suffix) == "lo"
  end

  test "split!/2 raises when splitting past the end" do
    assert_raise ArgumentError, fn -> IOData.split!(["ab"], 3) end
  end

  test "starts_with?/2 matches prefixes across integer elements" do
    assert IOData.starts_with?([?h, ?e, "llo"], "he")
    refute IOData.starts_with?([?h, ?e], "hx")
  end

  test "starts_with?/2 is true when the prefix ends inside a chunk" do
    assert IOData.starts_with?(["hello"], "he")
  end

  test "starts_with?/2 matches a prefix spanning multiple chunks" do
    assert IOData.starts_with?(["he", "llo"], "hel")
    refute IOData.starts_with?(["he", "llo"], "help")
  end

  test "to_iodata/3 returns an error when the start is past the end of an improper iolist" do
    assert IOData.to_iodata(["ab" | "cd"], 5, 1) == {:error, :insufficient_data}
  end

  test "to_iodata/3 returns an error when the count extends past an improper iolist" do
    assert IOData.to_iodata(["ab" | "cd"], 0, 5) == {:error, :insufficient_data}
  end

  test "to_iodata/3 extracts a range spanning an improper iolist's binary tail" do
    {:ok, iodata} = IOData.to_iodata(["ab" | "cd"], 1, 2)
    assert IO.iodata_to_binary(iodata) == "bc"
  end

  test "to_iodata/3 returns an error when the start is past the end" do
    assert IOData.to_iodata(["ab"], 5, 1) == {:error, :insufficient_data}
  end

  test "to_iodata/3 returns an error when the count extends past the end" do
    assert IOData.to_iodata(["ab"], 0, 5) == {:error, :insufficient_data}
    assert IOData.to_iodata(["ab", "cd"], 1, 5) == {:error, :insufficient_data}
  end

  test "to_iodata!/3 extracts the requested range" do
    assert IO.iodata_to_binary(IOData.to_iodata!(["he", "llo"], 1, 3)) == "ell"
  end

  test "to_iodata!/3 raises when the range extends past the end" do
    assert_raise ArgumentError, fn -> IOData.to_iodata!(["ab"], 0, 5) end
  end

  test "to_binary/3 returns an error when the range extends past the end" do
    assert IOData.to_binary(["ab"], 0, 5) == {:error, :insufficient_data}
  end

  test "to_binary!/3 extracts the requested range as a binary" do
    assert IOData.to_binary!(["he", [?l, "lo"]], 1, 3) == "ell"
  end

  test "to_binary!/3 raises when the range extends past the end" do
    assert_raise ArgumentError, fn -> IOData.to_binary!(["ab"], 1, 5) end
  end
end
