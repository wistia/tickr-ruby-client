$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))

require 'fakeweb'
require 'rspec'
require 'tickr_client'

# Requires supporting files with custom matchers and macros, etc,
# in ./support/ and its subdirectories.
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each {|f| require f}

RSpec.configure do |config|
  config.before(:all) do
    FakeWeb.allow_net_connect = false
  end

  config.before(:each) do
    FakeWeb.clean_registry
  end
end
