defmodule Fitparser.Crc do
  @moduledoc false

  @header_without_crc_size 12
  @header_with_crc_size 14
  @crc_size 2

  def validate_structure(
        <<header_size, _protocol, _profile::little-16, data_size::little-32, ".FIT",
          _rest::binary>> = data
      )
      when header_size >= @header_without_crc_size do
    required = header_size + data_size + @crc_size

    cond do
      byte_size(data) < required -> {:error, "Truncated FIT file"}
      byte_size(data) == required -> :ok
      true -> validate_structure(binary_part(data, required, byte_size(data) - required))
    end
  end

  def validate_structure(_), do: {:error, "Invalid FIT header"}

  def parse_error(data) do
    case validate_structure(data) do
      {:error, reason} -> reason
      :ok -> "Invalid FIT record stream"
    end
  end

  def valid_sections?(
        <<header_size, _protocol, _profile::little-16, data_size::little-32, ".FIT",
          _rest::binary>> = data
      )
      when header_size >= @header_without_crc_size and
             byte_size(data) >= header_size + data_size + @crc_size do
    header = binary_part(data, 0, header_size)
    body = binary_part(data, header_size, data_size)
    crc = file_crc(data, header_size, data_size)

    header_valid?(header) and body_valid?(body, crc) and
      case binary_part(
             data,
             header_size + data_size + @crc_size,
             byte_size(data) - header_size - data_size - @crc_size
           ) do
        <<>> -> true
        tail -> valid_sections?(tail)
      end
  end

  def valid_sections?(_), do: false

  def header_valid?(header) do
    header_size = byte_size(header)

    header_crc =
      :binary.decode_unsigned(binary_part(header, header_size - @crc_size, @crc_size), :little)

    header_size < @header_with_crc_size or header_crc == 0 or
      CRC.crc(:crc_16, binary_part(header, 0, header_size - @crc_size)) == header_crc
  end

  def body_valid?(body, crc), do: CRC.crc(:crc_16, body) == crc

  def file_crc(data, header_size, data_size),
    do: :binary.decode_unsigned(binary_part(data, header_size + data_size, @crc_size), :little)
end
