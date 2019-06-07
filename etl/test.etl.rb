# frozen_string_literal: true

require_relative '../config/environment'

# Run from bash:
# > bundle exec kiba etl/test.etl

# Run from a Rake task:
# task :etl => :environment do
#   etl_filename = 'etl/test.etl'
#   script_content = IO.read(etl_filename)
#   # pass etl_filename to line numbers on errors
#   job_definition = Kiba.parse(script_content, etl_filename)
#   Kiba.run(job_definition)
# end

puts 'Hello from Kiba!'
