# frozen_string_literal: true

require 'mysql2'

# = CsvSource
#
#  - Goggles framework vers.:  6.400
#  - author: Steve A.
#
#  Defines the base class for a Kiba Data destination set on a generic MySQL DB connection.
#
class MysqlDestination

  # Initializes the new instance & a dedicated database connection.
  def initialize
    config = Rails.application.config.database_configuration[Rails.env]
    @client = Mysql2::Client.new(
      host: config['host'],
      database: config['database'],
      username: config['username'],
      password: config['password']
    )
  end

  # Yields individual rows from the database connection.
  #         *IMPLEMENT THIS IN SUBCLASSES*
  # Use the available @client member to get the MySql client interface.
  #
  # Sample query using 'mysql2' gem:
  # results = @client.query("SELECT * FROM users WHERE group='githubbers'")
  #
  # statement = @client.prepare("SELECT * FROM users WHERE login_count = ?")
  # result1 = statement.execute(1)
  # result2 = statement.execute(2)
  #
  def write
    raise 'Please define this in a subclass. Use the available @client member.'
  end

  # Closes the database connection
  def close
    @client.close
    @client = nil
  end

end
