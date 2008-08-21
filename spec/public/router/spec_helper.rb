require File.join(File.dirname(__FILE__), "..", "..", "spec_helper")
require 'ostruct'
require "rubygems"
require "spec"

Dir[File.join(File.dirname(__FILE__), 'lib', '*.rb')].each do |file|
  require file
end

Spec::Runner.configure do |config|
  config.include(Spec::Helpers)
  config.include(Spec::Matchers)
  config.after(:each) do
    Merb::Router.reset!
  end
end