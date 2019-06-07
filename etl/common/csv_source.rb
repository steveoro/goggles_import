# frozen_string_literal: true

require 'csv'

# = CsvSource
#
#  - Goggles framework vers.:  6.400
#  - author: Steve A.
#
#  Defines the base class for a Kiba Data source set on a CSV file.
#
class CsvSource

  # Initializes the new instance
  def initialize(file_name, options)
    @file = file_name
    @options = options
  end

  # Yields individual rows from the CSV file
  def each
    CSV.foreach(@file, @options) do |row|
      yield row.to_hash
    end
  end

end
