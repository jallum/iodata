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
end
