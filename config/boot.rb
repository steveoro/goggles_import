# frozen_string_literal: true

ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../Gemfile', __dir__)
ENV['EXECJS_RUNTIME'] = 'Node' # [Steve A.] Force ExecJS runtime to be Node.JS (must be already installed)

require 'bundler/setup' # Set up gems listed in the Gemfile.
require 'bootsnap/setup' # Speed up boot time by caching expensive operations.
