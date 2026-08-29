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
      {:fitparser, "~> 0.4"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/fitparser>.

Use `Fitparser.Decoder.load_fit/2` for FIT bytes and
`Fitparser.Decoder.from_fit/2` for file paths. For faster decoding, component
fields are disabled by default; pass `expand_components: true` to expand them.
Fields preserve the order from the FIT definition; expanded component fields
follow their source field, and developer fields follow regular fields.
`Fitparser.Decoder.decode/2` and `decode!/2` are aliases for the
`load_fit` functions, matching the common FIT decoder API.

Pass `standard_units: true` to convert semicircle coordinates to degrees and
FIT boolean values to Elixir booleans.

Timestamps are returned as Unix seconds.

Custom processors can transform each decoded record. They may be modules
implementing `Fitparser.Processor`, `{module, options}` tuples, or one- or
two-argument functions:

```elixir
Fitparser.Decoder.decode!(data,
  processors: [MyProcessor, fn record -> record end]
)
```

Pass `include_metadata: true` to additionally receive `__headers__`,
`__definitions__`, and `__crcs__` entries containing FIT structural records.

Unknown messages and fields remain available as `message_<global>` and
`field_<number>` values, allowing files from newer FIT profiles to be read.

IEEE floating-point NaN values decode as `nil`; positive and negative infinity
decode as `:infinity` and `:negative_infinity`.
