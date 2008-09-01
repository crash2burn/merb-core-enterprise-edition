require File.join(File.dirname(__FILE__), "..", "..", "spec_helper")
require 'ostruct'
require "rubygems"
require "spec"

module Spec
  module Matchers
    class HaveRoute
      def initialize(expected, exact = false)
        @expected = expected
        @exact = exact
      end

      def matches?(target)
        @target = target.last
        @errors = []
        @expected.all? { |param, value| @target[param] == value } && (!@exact || @expected.length == @target.length)
      end

      def failure_message
        @target.each do |param, value|
          @errors << "Expected :#{param} to be #{@expected[param].inspect}, but was #{value.inspect}" unless
            @expected[param] == value
        end
        @errors << "Got #{@target.inspect}"
        @errors.join("\n")
      end

      def negative_failure_message
        "Expected #{@expected.inspect} not to be #{@target.inspect}, but it was."
      end

      def description() "have_route #{@target.inspect}" end
    end

    def have_route(expected)
      HaveRoute.new(expected)
    end
    
    def have_exact_route(expected)
      HaveRoute.new(expected, true)
    end
    
    class HaveNilRoute

      def matches?(target)
        @target = target
        target.last.empty?
      end

      def failure_message
        "Expected a nil route. Got #{@target.inspect}."
      end

      def negative_failure_message
        "Expected not to get a nil route."
      end
    end

    def have_nil_route
      HaveNilRoute.new
    end
  end
  
  module Helpers
    #
    # Creates a single route with the passed conditions and parameters without
    # registering it with Router
    # def route(conditions, params = {})
    #   conditions = {:path => conditions} unless Hash === conditions
    #   Merb::Router::Route.new(conditions, params)
    # end
    # 
    # #
    # # A shortcut for creating a single route and registering it with Router
    # def prepare_named_route(name, from, conditions = {}, to = nil)
    #   to, conditions = conditions, {} unless to
    #   Merb::Router.prepare {|r| r.match(from, conditions).to(to).name(name) }
    # end
    # 
    # def prepare_conditional_route(name, from, conditions, to = {})
    #   Merb::Router.prepare {|r| r.match(from, conditions).to(to).name(name) }
    # end
    # 
    def prepare_route(from = {}, to = {})
      name = :default
      Merb::Router.prepare {|r| r.match(from).to(to).name(name) }
    end
    
    def simple_request(options = {})
      Request.new({:protocol => "http://", :path => '/'}.merge(options))
    end

    #
    # Returns the dispatch parameters for a request by passing the request
    # through Router#match.
    def route_to(path, args = {}, protocol = "http://")
      request = Request.new({:protocol => protocol, :path => path}.merge(args))
      Merb::Router.match(request)
    end
    
    def match_for(path, args = {}, protocol = "http://")
      Merb::Router.match(Request.new({:protocol => protocol, :path => path}.merge(args)))
    end
    
    def matched_route_for(*args)
      # get route index
      idx = match_for(*args)[0]
    
      Merb::Router.routes[idx]
    end

    # Returns a generated URL from parameters
    # def url(name = {}, params = {})
    #   name, params = :default, name if Hash === name
    #   Merb::Router.generate(name, params)
    # end

    # Fake request object
    class Request < OpenStruct
      def initialize(hash)
        @table = {}
        hash.each_pair do |key, value|
          @table[key] = value.to_s
        end
      end
      
      def method
        @table[:method] || "get"
      end

      def params
        @table
      end
    end
  end
end

Spec::Runner.configure do |config|
  config.include(Spec::Helpers)
  config.include(Spec::Matchers)
  config.before(:each) do
    @_root_behavior = Merb::Router.root_behavior
  end
  config.after(:each) do
    Merb::Router.root_behavior = @_root_behavior
    Merb::Router.reset!
  end
end