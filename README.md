# Fitparser
Elixir library used to decode [FIT files](https://developer.garmin.com/fit/overview/).

The decoder is implemented entirely in Elixir and does not require Rust, a
compiler, or a native library at runtime.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `fitparser` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:fitparser, "~> 0.5"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/fitparser>.

## Usage

Use `Fitparser.Decoder.load_fit/2` for FIT bytes and
`Fitparser.Decoder.from_fit/2` for file paths:

```elixir
{:ok, records} = Fitparser.Decoder.from_fit("activity.fit")

for record <- Map.get(records, :record, []) do
  Enum.each(record.fields, &IO.inspect/1)
end
```

Known messages are grouped under atom keys such as `:record` and `:session`.
Each value is a list of `%Fitparser.FitDataRecord{}` structs containing
`%Fitparser.FitDataField{}` fields.

### Options

- `expand_components: true` expands component fields. It is disabled by default
  for faster decoding.
- `standard_units: true` converts semicircle coordinates to degrees and FIT
  booleans to Elixir booleans.
- `validate_crc: true` validates FIT header and data CRCs.
- `include_metadata: true` adds `"__headers__"`, `"__definitions__"`, and
  `"__crcs__"` structural records.
- `processors: [...]` applies record processors after decoding.

Fields preserve the order from the FIT definition; expanded component fields
follow their source field, and developer fields follow regular fields.
`Fitparser.Decoder.decode/2` and `decode!/2` are aliases for the
`load_fit` functions, matching the common FIT decoder API.

Timestamps are returned as Unix seconds.
`local_timestamp` values have no timezone embedded in FIT; when available,
timezone information is returned in its source message (for example,
`utc_offset`, `time_zone_offset`, or sleep start/end offsets).

Custom processors can transform each decoded record. They may be modules
implementing `Fitparser.Processor`, `{module, options}` tuples, or one- or
two-argument functions:

```elixir
Fitparser.Decoder.decode!(data,
  processors: [MyProcessor, fn record -> record end]
)
```

Unknown messages and fields remain available as `message_<global>` and
`field_<number>` values, allowing files from newer FIT profiles to be read.
Unknown messages and fields remain available as `"message_<global>"` and
`"field_<number>"` values, allowing files from newer FIT profiles to be read.
Fields with an unknown FIT base type return their original raw binary value.

IEEE floating-point NaN values decode as `nil`; positive and negative infinity
decode as `:infinity` and `:negative_infinity`.
