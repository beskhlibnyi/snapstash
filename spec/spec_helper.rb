require "tmpdir"
require "rack/test"
require_relative "../app"

RSpec.configure do |config|
  config.disable_monkey_patching!
  config.example_status_persistence_file_path = ".rspec_status"
  config.order = :random
  Kernel.srand config.seed

  config.around do |example|
    original_env = ENV.to_hash
    example.run
  ensure
    ENV.replace(original_env)
  end
end
