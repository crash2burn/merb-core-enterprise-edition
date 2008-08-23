module Merb
  class Router
    #
    # Behavior has been refactored so that it's only purpose is to describe routes.
    #
    # As of now, it collects only two things: conditions and params. When a new
    # condition or param has the same key as an older one, the new one overwrites
    # the old one. This is true for all cases EXCEPT conditions[:path].
    #
    # When nesting behaviors, conditions[:path] is appended to. I didn't want to
    # handle any of of the logic of joining strings with other strings and
    # regular expressions in Behavior, so I store conditions[:path] as an Array.
    # Everytime a new condition[:path] is defined, it is appended to the Array.
    # All the logic to merge the elements of the Array is in Route.
    class Behavior

      class Error < StandardError; end;

      def initialize(conditions = {}, params = {}, defaults = {}, options = {})
        @conditions = conditions
        @params     = params
        @defaults   = defaults
        @options    = options

        stringify_condition_values
      end

      # Register a new route.
      #
      # ==== Parameters
      # path<String, Regex>:: The url path to match
      # params<Hash>:: The parameters the new routes maps to.
      #
      # ==== Returns
      # Route:: The resulting Route.
      #---
      # @public
      def add(path, params = {})
        match(path).to(params)
      end

      # Matches a +path+ and any number of optional request methods as
      # conditions of a route. Alternatively, +path+ can be a hash of
      # conditions, in which case +conditions+ ignored.
      #
      # ==== Parameters
      #
      # path<String, Regexp>::
      #   When passing a string as +path+ you're defining a literal definition
      #   for your route. Using a colon, ex.: ":login", defines both a capture
      #   and a named param.
      #   When passing a regular expression you can define captures explicitly
      #   within the regular expression syntax.
      #   +path+ is optional.
      # conditions<Hash>::
      #   Addational conditions that the request must meet in order to match.
      #   the keys must be methods that the Merb::Request instance will respond
      #   to.  The value is the string or regexp that matched the returned value.
      #   Conditions are inherited by child routes.
      #
      #   The Following have special meaning:
      #   * :method -- Limit this match based on the request method. (GET,
      #     POST, PUT, DELETE)
      #   * :path -- Used internally to maintain URL form information
      #   * :controller and :action -- These can be used here instead of '#to', and
      #     will be inherited in the block.
      #   * :params -- Sets other key/value pairs that are placed in the params
      #     hash. The value must be a hash.
      # &block::
      #   Passes a new instance of a Behavior object into the optional block so
      #   that sub-matching and routes nesting may occur.
      #
      # ==== Returns
      # Behavior::
      #   A new instance of Behavior with the specified path and conditions.
      #
      # +Tip+: When nesting always make sure the most inner sub-match registers
      # a Route and doesn't just returns new Behaviors.
      #
      # ==== Examples
      #
      #   # registers /foo/bar to controller => "foo", :action => "bar"
      #   # and /foo/baz to controller => "foo", :action => "baz"
      #   r.match "/foo", :controller=>"foo" do |f|
      #     f.match("/bar").to(:action => "bar")
      #     f.match("/baz").to(:action => "caz")
      #   end
      #
      #   #match only of the browser string contains MSIE or Gecko
      #   r.match ('/foo', :user_agent => /(MSIE|Gecko)/ )
      #        .to({:controller=>'foo', :action=>'popular')
      #
      #   # Route GET and POST requests to different actions (see also #resources)
      #   r.match('/foo', :method=>:get).to(:action=>'show')
      #   r.mathc('/foo', :method=>:post).to(:action=>'create')
      #
      #   # match also takes regular expressions
      #
      #   r.match(%r[/account/([a-z]{4,6})]).to(:controller => "account",
      #      :action => "show", :id => "[1]")
      #
      #   r.match(/\/?(en|es|fr|be|nl)?/).to(:language => "[1]") do |l|
      #     l.match("/guides/:action/:id").to(:controller => "tour_guides")
      #   end
      #---
      # @public
      def match(path = {}, conditions = {}, &block)
        path, conditions = path[:path], path if Hash === path
        conditions[:path] = merge_paths(path)

        raise Error, "The route has already been committed. Further conditions cannot be specified" if @route

        behavior = self.class.new(@conditions.merge(conditions), @params, @defaults, @options)
        yield behavior if block_given?
        behavior
      end

      # Combines common case of match being used with
      # to({}).
      #
      # ==== Returns
      # <Route>:: route that uses params from named path segments.
      #
      # ==== Examples
      # r.match!("/api/:token/:controller/:action/:id")
      #
      # is the same thing as
      #
      # r.match!("/api/:token/:controller/:action/:id").to({})
      def match!(path = '', conditions = {}, &block)
        match(path, conditions, &block).to({})
      end

      def to_route(params = {}, &conditional_block)
        params = @params.merge(params)

        raise Error, "The route has already been committed." if @route

        # I'm not sure if this is the best way to implement namespaces. Maybe
        # the namespace should be passed to Route and Route handles it however.
        if @options[:controller_prefix]
          controller = params[:controller] || ":controller"
          params[:controller] = (@options[:controller_prefix] + [controller]).compact.join('/')
        end

        @route = Route.new(@conditions, params, :defaults => @defaults, &conditional_block)
        self
      end

      def fixatable(enable = true)
        @route.fixatable(enable)
        self
      end

      def register
        @route.register
        self
      end

      def name(prefix, symbol = nil)
        unless symbol
          symbol, prefix = prefix, nil
        end

        name = [prefix, @options[:name_prefix], symbol].flatten.compact.join('_')
        @route.name(name.intern)

        self
      end

      def full_name(symbol)
        @route.name(symbol)
        self
      end

      # Creates a Route from one or more Behavior objects, unless a +block+ is
      # passed in.
      #
      # ==== Parameters
      # params<Hash>:: The parameters the route maps to.
      # &block::
      #   Optional block. A new Behavior object is yielded and further #to
      #   operations may be called in the block.
      #
      # ==== Block parameters
      # new_behavior<Behavior>:: The child behavior.
      #
      # ==== Returns
      # Route:: It registers a new route and returns it.
      #
      # ==== Examples
      #   r.match('/:controller/:id).to(:action => 'show')
      #
      #   r.to :controller => 'simple' do |s|
      #     s.match('/test').to(:action => 'index')
      #     s.match('/other').to(:action => 'other')
      #   end
      #---
      # @public
      def to(params = {}, &block)
        raise Error, "The route has already been committed. Further params cannot be specified" if @route

        behavior = self.class.new(@conditions, @params.merge(params), @defaults, @options)
        
        if block_given?
          yield behavior if block_given?
          behavior
        else
          behavior.to_route(params).register
        end
      end

      def defaults(defaults = {}, &block)
        behavior = self.class.new(@conditions, @params, @defaults.merge(defaults), @options)
        yield behavior if block_given?
        behavior
      end

      def options(opts = {}, &block)
        options = @options.dup

        opts.each_pair do |key, value|
          options[key] = (options[key] || []) + [value.freeze]
        end

        behavior = self.class.new(@conditions, @params, @defaults, options)
        yield behavior if block_given?
        behavior
      end

      # Takes a block and stores it for deferred conditional routes. The block
      # takes the +request+ object and the +params+ hash as parameters.
      #
      # ==== Parameters
      # params<Hash>:: Parameters and conditions associated with this behavior.
      # &conditional_block::
      #   A block with the conditions to be met for the behavior to take
      #   effect.
      #
      # ==== Returns
      # Route :: The default route.
      #
      # ==== Examples
      #   r.defer_to do |request, params|
      #     params.merge :controller => 'here',
      #       :action => 'there' if request.xhr?
      #   end
      #---
      # @public
      def defer_to(params = {}, &conditional_block)
        to_route(params, &conditional_block).register
      end

      # Creates the most common routes /:controller/:action/:id.format when
      # called with no arguments.
      # You can pass a hash or a block to add parameters or override the default
      # behavior.
      #
      # ==== Parameters
      # params<Hash>::
      #   This optional hash can be used to augment the default settings
      # &block::
      #   When passing a block a new behavior is yielded and more refinement is
      #   possible.
      #
      # ==== Returns
      # Route:: the default route
      #
      # ==== Examples
      #
      #   # Passing an extra parameter "mode" to all matches
      #   r.default_routes :mode => "default"
      #
      #   # specifying exceptions within a block
      #   r.default_routes do |nr|
      #     nr.defer_to do |request, params|
      #       nr.match(:protocol => "http://").to(:controller => "login",
      #         :action => "new") if request.env["REQUEST_URI"] =~ /\/private\//
      #     end
      #   end
      #---
      # @public
      def default_routes(params = {}, &block)
        match("/:controller(/:action(/:id))(.:format)").to(params, &block).name(:default)
      end

      # Creates a namespace for a route. This way you can have logical
      # separation to your routes.
      #
      # ==== Parameters
      # name_or_path<String, Symbol>:: The name or path of the namespace.
      # options<Hash>:: Optional hash, set :path if you want to override what appears on the url
      # &block::
      #   A new Behavior instance is yielded in the block for nested resources.
      #
      # ==== Block parameters
      # r<Behavior>:: The namespace behavior object.
      #
      # ==== Examples
      #   r.namespace :admin do |admin|
      #     admin.resources :accounts
      #     admin.resource :email
      #   end
      #
      #   # /super_admin/accounts
      #   r.namespace(:admin, :path=>"super_admin") do |admin|
      #     admin.resources :accounts
      #   end
      #---
      # @public
      def namespace(name_or_path, opts = {}, &block)
        name = name_or_path.to_s # We don't want this modified ever
        path = opts[:path] || name

        raise Error, "The route has already been committed. Further options cannot be specified" if @route

        # option keys could be nil
        opts[:controller_prefix] = name unless opts.has_key?(:controller_prefix)
        opts[:name_prefix]       = name unless opts.has_key?(:name_prefix)

        behavior = self
        behavior = behavior.match("/#{path}") unless path.empty?
        behavior.options(opts, &block)
      end

      def redirect(url, permanent = true)
        raise Error, "The route has already been committed." if @route

        status = permanent ? 301 : 302
        @route = Route.new(@conditions, {:url => url.freeze, :status => status.freeze}, :redirects => true).register
        self
      end

    protected

      def stringify_condition_values
        @conditions.each do |key, value|
          unless value.nil? || Regexp === value || Array === value
            @conditions[key] = value.to_s
          end
        end
      end

    private

      def merge_paths(path)
        [@conditions[:path], path.freeze].flatten.compact
      end

    end
  end
end