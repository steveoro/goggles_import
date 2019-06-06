# Guardfile - More info at https://github.com/guard/guard#readme

## Uncomment and set this to only include directories you want to watch
# directories %w(app lib config test spec features) \
#  .select{|d| Dir.exists?(d) ? d : UI.warning("Directory #{d} does not exist")}

## Note: if you are using the `directories` clause above and you are not
## watching the project directory ('.'), then you will want to move
## the Guardfile to a watched dir and symlink it back, e.g.
#
#  $ mkdir config
#  $ mv Guardfile config/
#  $ ln -s config/Guardfile .
#
# and, you'll have to watch "config/Guardfile" instead of "Guardfile"


# Watch the bundle for updates:
guard :bundler do
  watch('Gemfile')
end

# Start explicitly the Spring preloader & watch for files that may need Spring to refresh itself:
guard :spring, bundler: true do
  watch('Gemfile.lock')
  watch(%r{^config/})
  watch(%r{^spec/(support|factories)/})
  watch(%r{^spec/factory.rb})
end


rspec_options = {
  cmd: "spring rspec",
  # Exclude performance tests with fail-fast:
  # cmd_additional_args: "--color -f progress --order rand --fail-fast -t ~type:performance",
  cmd_additional_args: " --color -f progress --order rand -t ~type:performance",
  all_after_pass: false,
  failed_mode: :focus
}
# Note: The cmd option is now required due to the increasing number of ways
#       rspec may be run, below are examples of the most common uses.
#  * bundler: 'bundle exec rspec'
#  * bundler binstubs: 'bin/rspec'
#  * spring: 'bin/rspec' (This will use spring if running and you have
#                          installed the spring binstubs per the docs)
#  * zeus: 'zeus rspec' (requires the server to be started separately)
#  * 'just' rspec: 'rspec'

# Watch everything RSpec-related and run it:
guard :rspec, rspec_options do
  require "guard/rspec/dsl"
  dsl = Guard::RSpec::Dsl.new(self)

  # RSpec files:
  rspec = dsl.rspec
  watch(rspec.spec_helper)  { rspec.spec_dir }
  watch(rspec.spec_support) { rspec.spec_dir }
  watch(rspec.spec_files)
  # Ruby files:
  ruby = dsl.ruby
  dsl.watch_spec_files_for(ruby.lib_files)
  # Rails files:
  rails = dsl.rails(view_extensions: %w(erb haml slim))
  dsl.watch_spec_files_for(rails.app_files)
  dsl.watch_spec_files_for(rails.views)

  watch(rails.controllers) do |m|
    [
      rspec.spec.call("routing/#{m[1]}_routing"),
      rspec.spec.call("controllers/#{m[1]}_controller")
    ]
  end
  # Watch factories and launch the corresponding model specs:
  watch( %r{^spec/factories/(.+)\.rb$} ) do |m|
    Dir[
      "spec/models/#{ m[1] }*spec.rb"
    ]
  end
  # Rails config changes:
  watch(rails.spec_helper)     { rspec.spec_dir }
  watch(rails.routes)          { "#{rspec.spec_dir}/routing" }
  watch(rails.app_controller)  { "#{rspec.spec_dir}/controllers" }
  watch(rails.spec_helper)     { "#{rspec.spec_dir}/factories" }
  # [Steve A.] Commented-out so that we don't run feature specs inside RSpec:
  # Capybara features specs
  # watch(rails.view_dirs)     { |m| rspec.spec.call("features/#{m[1]}") }
  # watch(rails.layouts)       { |m| rspec.spec.call("features/#{m[1]}") }
end


rubocop_options = {
  cmd: "spring rubocop",
  # With fuubar, offenses and warnings tot.:
  # cli: "-R -E -P -f fu -f o -f w"
  cli: "-R -E -P"
}

# Watch Ruby files for changes and run RuboCop:
# [See https://github.com/yujinakayama/guard-rubocop for all options]
guard :rubocop, rubocop_options do
  watch(%r{.+\.rb$})
  watch(%r{(?:.+/)?\.rubocop(?:_todo)?\.yml$}) { |m| File.dirname(m[0]) }
end


cucumber_options = {
  cmd: "spring cucumber",
  cmd_additional_args: "--profile guard",
  notification: false, all_after_pass: false, all_on_start: false
}

# Watch everything Cucumber-related and run it:
guard :cucumber, cucumber_options do
  # Watch for feature updates:
  watch( %r{^features\/(.+/)?(.+)\.feature$} ) do |m|
    puts "'#{ m[0] }' modified..."
    m[0]
  end
  # Watch for support file updates (will trigger a re-run of all features):
  watch( %r{^features\/support/.+$} ) do |m|
    puts "'#{ m[0] }' support file modified..."
    Dir[File.join( "features\/\*\/*.feature" )]
  end
  # Watch for step definition updates (will trigger a re-run of a whole feature):
  watch( %r{^features\/step_definitions\/(.+)_steps\.rb$} ) do |m|
    puts "'#{ m[1] }' steps file modified..."
    Dir[File.join( "features\/\*\/*#{m[1]}*.feature" )]
  end
end

