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
    # Allow real HTTP connections only to our local tickr server
    FakeWeb.allow_net_connect = %r[^https?://localhost]
  end

  config.before(:each) do
    FakeWeb.clean_registry
  end
end

def with_silenced_output
  orig_stderr = $stderr
  orig_stdout = $stdout
  $stderr = File.new('/dev/null', 'w')
  $stdout = File.new('/dev/null', 'w')
  yield
  $stderr = orig_stderr
  $stdout = orig_stdout
end
