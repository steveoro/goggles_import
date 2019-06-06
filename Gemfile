source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby '2.5.3'

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'rails', '~> 5.1.6'

gem 'mysql2'
gem 'activerecord-session_store' # Needed to include a DB-based session store in Rails 4+

# Use Puma as the app server
gem 'puma', '~> 3.11'
# Use SCSS for stylesheets
gem 'sass-rails', '~> 5.0'
# Use Uglifier as compressor for JavaScript assets
gem 'uglifier', '>= 1.3.0'
# See https://github.com/rails/execjs#readme for more supported runtimes
# gem 'mini_racer', platforms: :ruby

# Use CoffeeScript for .coffee assets and views
gem 'coffee-rails', '~> 4.2'
# Turbolinks makes navigating your web application faster. Read more: https://github.com/turbolinks/turbolinks
gem 'turbolinks', '~> 5'

# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem 'jbuilder', '~> 2.5'

# Use Redis adapter to run Action Cable in production
# gem 'redis', '~> 4.0'
# Use ActiveModel has_secure_password
# gem 'bcrypt', '~> 3.1.7'

# Use ActiveStorage variant
# gem 'mini_magick', '~> 4.8'

# Use Capistrano for deployment
# gem 'capistrano-rails', group: :development

# Reduces boot times through caching; required in config/boot.rb
gem 'bootsnap', '>= 1.1.0', require: false

gem 'haml-rails'                # Haml templating & generator engine
gem 'kiba'                      # ETL & reporting (https://github.com/thbar/kiba)
gem 'awesome_print'             # Pretty-print any object

gem 'bootstrap', '~> 4.3.1'
gem 'draper'                    # Decorator for models
gem 'font-awesome-rails'

# Use jquery as the JavaScript library
gem 'jquery-rails'
gem 'jquery-ui-rails'

gem 'grape'                     # API
gem 'grape-route-helpers'
gem 'rest-client'

# Core Engine (When using the ssh key use the "git@github.com" protocol.)
gem "goggles_core", git: "git@github.com:steveoro/goggles_core"
gem "amistad", git: "https://github.com/fasar-sw/amistad", branch: "rails5"

group :development, :test do
  gem 'bullet'
  # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem 'byebug', platforms: [:mri, :mingw, :x64_mingw]

  gem "letter_opener"

  gem "rspec"
  gem "rspec-rails"
  gem "factory_bot_rails"
  gem "ffaker"                  # Adds dummy names & fixture generator

  gem 'rubocop', require: false # For style checking
  gem 'rubocop-rspec'
  gem 'rubocop-rails'
end

group :development do
  gem 'guard'
  gem 'guard-bundler', require: false
  gem 'guard-cucumber'
  gem 'guard-rspec'
  gem 'guard-rubocop'
  gem 'guard-shell'
  gem 'guard-spring'

  # Access an interactive console on exception pages or by calling 'console' anywhere in the code.
  gem 'web-console', '>= 3.3.0'
  gem 'listen', '>= 3.0.5', '< 3.2'
  # Spring speeds up development by keeping your application running in the background. Read more: https://github.com/rails/spring
  gem 'spring'
  gem 'spring-watcher-listen', '~> 2.0.0'
  gem 'spring-commands-cucumber'
  gem 'spring-commands-rspec'
end

group :test do
  # Adds support for Capybara system testing and selenium driver
  gem 'capybara', '>= 2.15'
  gem 'cucumber'
  gem 'cucumber-rails', require: false

  gem 'selenium-webdriver'
  # Easy installation and use of chromedriver to run system tests with Chrome
  gem 'webdrivers'
  gem 'webmock'
end

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
# gem 'tzinfo-data', platforms: [:mingw, :mswin, :x64_mingw, :jruby]
