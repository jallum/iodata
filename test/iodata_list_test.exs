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
end
