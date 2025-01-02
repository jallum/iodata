defmodule IODataSliceTest do
  use ExUnit.Case
  use ExUnitProperties

  alias IOData.Slice

  property "at_least? checks whether the slice contains enough bytes" do
    check all(
            iodata <- binary(),
            start <- integer(0..byte_size(iodata)),
            count <- one_of([constant(nil), integer(0..byte_size(iodata))]),
            n_bytes <- integer(0..(count || byte_size(iodata) - start))
          ) do
      slice = %Slice{iodata: iodata, start: start, count: count}

      expected =
        if count == nil, do: IOData.at_least?(iodata, start + n_bytes), else: count >= n_bytes

      assert IOData.at_least?(slice, n_bytes) == expected
    end
  end

  property "split divides the slice into two parts" do
    check all(
            iodata <- binary(),
            start <- integer(0..byte_size(iodata)),
            count <- one_of([constant(nil), integer(0..byte_size(iodata))]),
            at <- integer(0..(count || byte_size(iodata) - start))
          ) do
      slice = %Slice{iodata: iodata, start: start, count: count}

      if at > (count || byte_size(iodata) - start) do
        assert {:error, :insufficient_data} == IOData.split(slice, at)
      else
        {:ok, {head_slice, tail_slice}} = IOData.split(slice, at)
        head_count = if count, do: min(at, count), else: at
        tail_count = if count, do: count - head_count, else: nil
        assert head_slice == %Slice{iodata: iodata, start: start, count: head_count}
        assert tail_slice == %Slice{iodata: iodata, start: start + head_count, count: tail_count}
      end
    end
  end

  property "starts_with? correctly identifies prefix" do
    check all(
            iodata <- binary(),
            start <- integer(0..byte_size(iodata)),
            count <- one_of([constant(nil), integer(0..byte_size(iodata))]),
            prefix <- binary(min_length: 0, max_length: 10)
          ) do
      slice = %Slice{iodata: iodata, start: start, count: count}

      case IOData.to_binary(slice.iodata, slice.start, byte_size(prefix)) do
        {:ok, data} -> assert IOData.starts_with?(slice, prefix) == (data == prefix)
        {:error, _} -> refute IOData.starts_with?(slice, prefix)
      end
    end
  end

  property "to_binary reads the correct binary data from the slice" do
    check all(
            iodata <- binary(),
            start <- integer(0..byte_size(iodata)),
            count <- one_of([constant(nil), integer(0..(byte_size(iodata) - start))])
          ) do
      slice = %Slice{iodata: iodata, start: start, count: count}
      expected_data = binary_part(iodata, start, count || byte_size(iodata) - start)
      assert {:ok, ^expected_data} = IOData.to_binary(slice)
    end
  end

  property "to_binary/3 reads the correct binary data from the slice" do
    check all(
            iodata <- binary(),
            start <- integer(0..byte_size(iodata)),
            count <- integer(0..(byte_size(iodata) - start))
          ) do
      slice = %Slice{iodata: iodata, start: 0, count: byte_size(iodata)}
      {:ok, expected_data} = IOData.to_binary(slice, start, count)
      assert expected_data == binary_part(iodata, start, count)
    end
  end

  property "to_iodata returns the correct iodata from the slice" do
    check all(
            iodata <- binary(),
            start <- integer(0..byte_size(iodata)),
            count <- one_of([constant(nil), integer(0..(byte_size(iodata) - start))])
          ) do
      slice = %Slice{iodata: iodata, start: 0, count: nil}
      expected_data = binary_part(iodata, start, count || byte_size(iodata) - start)
      assert {:ok, ^expected_data} = IOData.to_iodata(slice, start, count)
    end
  end

  property "to_iodata/3 returns the correct iodata from the slice" do
    check all(
            iodata <- binary(),
            start <- integer(0..byte_size(iodata)),
            count <- integer(0..(byte_size(iodata) - start))
          ) do
      slice = %Slice{iodata: iodata, start: 0, count: byte_size(iodata)}
      {:ok, expected_data} = IOData.to_iodata(slice, start, count)
      assert expected_data == binary_part(iodata, start, count)
    end
  end
end
