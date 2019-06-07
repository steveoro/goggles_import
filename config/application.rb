# frozen_string_literal: true

require_relative 'boot'

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)
require 'goggles_core'

module GogglesImport
  class Application < Rails::Application

    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 5.1

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration can go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded after loading
    # the framework and any gems in your application.

    # Custom directories with classes and modules you want to be autoloadable.
    config.autoload_paths += %W[#{config.root}/app/strategies #{config.root}/app/daos]
    config.autoload_paths += GogglesCore::Engine.config.eager_load_paths # OR autoload_paths

  end
end
