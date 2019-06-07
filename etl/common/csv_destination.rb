# frozen_string_literal: true

require 'csv'

# = CSVDestination
#
#  - Goggles framework vers.:  6.400
#  - author: Steve A.
#
#  Defines the base class for a Kiba Data destination set on a CSV file.
#
class CSVDestination

  # Initializes the new instance
  def initialize(file_name, output_fields)
    @csv = CSV.open(file_name, 'w')
    @output_fields = output_fields
    @csv << @output_fields
  end

  # Writes a single row to the CSV file
  def write(data_row)
    @csv << data_row.values_at(*@output_fields)
  end

  # Closes the generated CSV file
  def close
    @csv.close
  end

end
