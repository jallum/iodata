[![Build Status](https://github.com/jallum/iodata/workflows/CI/badge.svg)](https://github.com/jallum/iodata/actions) [![Hex.pm](https://img.shields.io/hexpm/v/iodata.svg)](https://hex.pm/packages/iodata) [![Documentation](https://img.shields.io/badge/documentation-gray)](https://hexdocs.pm/iodata/)

---

# IOData

A protocol for efficently working with data (like binaries and iolists) with 
minimal copying. 

Implementations are provided for

- binaries
- iolists
- file descriptors

## Usage

Splitting a binary or iolist at a given index:

```elixir
iex> IOData.split!("hello world", 5)
{"hello", " world"}

iex> IOData.split!(["h", "ello", [[" "], "world"]], 5)
{["h", "ello"], [[[" "], "world"]]}
```

Slicing out a section of a binary or iolist:

```elixir
iex> IOData.to_iodata!("hello world", 4, 5)
"o wor"

iex> IOData.to_iodata!(["h", "ello", [[" "], "world"]], 4, 5)
["o", " ", "wor"]
```

Slicing out a section of a binary or iolist while converting it to a binary:

```elixir
iex> IOData.to_binary!("hello world", 4, 5)
"o wor"

iex> IOData.to_binary!(["h", "ello", [[" "], "world"]], 4, 5)
"o wor"
```

Determining whether an IOData has at least n bytes (without counting them _all_):

```elixir
iex> IOData.at_least?("hello world", 4)
true

iex> IOData.at_least?(["h", "ello", [[" "], "world"]], 4)
true
```
