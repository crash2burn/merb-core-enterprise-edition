require 'merb-core/dispatch/router/cached_proc'
require 'merb-core/dispatch/router/behavior'
require 'merb-core/dispatch/router/resources'
require 'merb-core/dispatch/router/route'

module Merb
  # Router stores route definitions and finds the first
  # route that matches the incoming request URL.
  #
  # Then information from route is used by dispatcher to
  # call action on the controller.
  #
  # ==== Routes compilation.
  #
  # The most interesting method of Router (and heart of
  # route matching machinery) is match method generated
  # on the fly from routes definitions. It is called routes
  # compilation. Generated match method body contains
  # one if/elsif statement that picks the first matching route
  # definition and sets values to named parameters of the route.
  #
  # Compilation is synchronized by mutex.
  class Router
    @@routes = []
    @@named_routes = {}
    @@compiler_mutex = Mutex.new

    # Raised when route lookup fails.
    class RouteNotFound < StandardError; end;
    # Raised when parameters given to generation
    # method do not match route parameters.
    class GenerationError < StandardError; end;
    class NotCompiledError < StandardError; end;

    cattr_accessor :routes, :named_routes

    class << self
      # Finds route matching URI of the request and
      # returns a tuple of [route index, route params].
      #
      # ==== Parameters
      # request<Merb::Request>:: request to match.
      #
      # ==== Returns
      # <Array(Integer, Hash)::
      #   Two-tuple: route index and route parameters. Route
      #   parameters are :controller, :action and all the named
      #   segments of the route.
      def route_for(request)
        index, params = match(request)
        route = routes[index] if index
        if !route
          raise ControllerExceptions::NotFound, 
            "No routes match the request: #{request.uri}"
        end
        [route, params]
      end
      
      # Clears routes table.
      def reset!
        class << self
          alias_method :match, :match_before_compilation
        end
        self.routes, self.named_routes = [], {}
      end

      # Appends route in the block to routing table.
      def append(&block)
        prepare(routes, [], &block)
      end

      # Prepends routes in the block to routing table.
      def prepend(&block)
        prepare([], routes, &block)
      end

      # Yields router scope to the block and inserts resulting routes
      # between +first+ and +last+ in resulting routing table.
      #
      # Compiles routes after block evaluation.
      def prepare(first = [], last = [], &block)
        self.routes = []
        yield Behavior.new({}, {}, {:action => "index"})
        self.routes = first + routes + last
        compile
        self
      end

      # Looks up route by name and generates URL using
      # given parameters. Raises GenerationError if
      # passed parameters do not match those of route.
      def generate(name, *args)
        unless route = @@named_routes[name.to_sym]
          raise GenerationError, "Named route not found: #{name}"
        end
        
        # As of now, only a has is accepted
        params = extract_options_from_args!(args) || { :id => args.first }
        
        route.generate(params) or raise GenerationError, "Named route #{name} could not be generated with #{params.inspect}"
      end
      
      def generate2(name, *args)
        unless route = @@named_routes[name.to_sym]
          raise GenerationError, "Named route not found: #{name}"
        end
        
        # As of now, only a has is accepted
        params = extract_options_from_args!(args) || { :id => args.first }
        
        route.generate2(params) or raise GenerationError, "Named route #{name} could not be generated with #{params.inspect}"
      end

      # Defines method with a switch statement that does routes recognition.
      def compile
        if routes.any?
          eval(compiled_statement, binding, "Generated Code for Merb::Router#match(#{__FILE__}:#{__LINE__})", 1)
        else
          reset!
        end
      end

      def match_before_compilation(request)
        raise NotCompiledError, "The routes have not been compiled yet"
      end

      alias_method :match, :match_before_compilation

    private

      # Generates method that does route recognition with a switch statement.
      def compiled_statement
        @@compiler_mutex.synchronize do
          condition_keys, if_statements = Set.new, ""

          routes.each_with_index do |route, i|
            route.freeze
            route.conditions.keys.each { |key| condition_keys << key }
            if_statements << route.compiled_statement(i == 0)
          end

          @@statement =  "def match(request)\n"
          @@statement << condition_keys.inject("") do |cached, key|
            cached << "  cached_#{key} = request.#{key}.to_s\n"
          end
          @@statement <<    if_statements
          @@statement << "  else\n"
          @@statement << "    [nil, {}]\n"
          @@statement << "  end\n"
          @@statement << "end"
        end
      end

    end # class << self
  end
end
