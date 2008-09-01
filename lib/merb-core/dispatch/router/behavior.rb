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
    # ---
    # @private
    class Behavior

      class Error < StandardError; end;
      
      # Proxy catches any methods and proxies them to the current behavior.
      # This allows building routes without constantly having to catching the
      # yielded behavior object
      # ---
      # @private
      class Proxy
        # Undefine as many methods as possible so that everything can be proxied
        # along to the behavior
        instance_methods.each { |m| undef_method m unless %w[ __id__ __send__ class kind_of? respond_to? assert_kind_of should should_not instance_variable_set instance_variable_get instance_eval].include?(m) }
        
        def initialize
          @behaviors = []
        end
        
        def push(behavior)
          @behaviors.push(behavior)
        end
        
        def pop
          @behaviors.pop
        end
        
        def respond_to?(*args)
          super || @behaviors.last.respond_to?(*args)
        end
        
      private
      
        def method_missing(method, *args, &block)
          behavior = @behaviors.last
          
          if behavior.respond_to?(method)
            behavior.send(method, *args, &block)
          else
            super
          end
        end
      end

      # Behavior objects are used for the Route building DSL. Each object keeps
      # track of the current definitions for the level at which it is defined.
      # Each time a method is called on a Behavior object that accepts a block,
      # a new instance of the Behavior class is created.
      #
      # ==== Parameters
      #
      # proxy<Proxy>::
      #   This is the object initialized by Merb::Router.prepare that tracks the
      #   current Behavior object stack so that Behavior methods can be called
      #   without explicitly calling them on an instance of Behavior.
      # conditions<Hash>::
      #   The initial route conditions. See #match.
      # params<Hash>::
      #   The initial route parameters. See #to.
      # defaults<Hash>::
      #   The initial route default parameters. See #defaults.
      # options<Hash>::
      #   The initial route options. See #options.
      #
      # ==== Returns
      # Behavior:: The initialized Behavior object
      #---
      # @private
      def initialize(proxy = nil, conditions = {}, params = {}, defaults = {}, identifiers = {}, options = {})
        @proxy       = proxy
        @conditions  = conditions
        @params      = params
        @defaults    = defaults
        @identifiers = identifiers
        @options     = options

        stringify_condition_values
      end

      # Matches a +path+ and any number of optional request methods as
      # conditions of a route. Alternatively, +path+ can be a hash of
      # conditions, in which case +conditions+ is ignored.
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
      #   Additional conditions that the request must meet in order to match.
      #   The keys must be methods that the Merb::Request instance will respond
      #   to.  The value is the string or regexp that matched the returned value.
      #   Conditions are inherited by child routes.
      #
      #   The following have special meaning:
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
      #   #match only if the browser string contains MSIE or Gecko
      #   r.match ('/foo', :user_agent => /(MSIE|Gecko)/ )
      #        .to({:controller=>'foo', :action=>'popular')
      #
      #   # Route GET and POST requests to different actions (see also #resources)
      #   r.match('/foo', :method=>:get).to(:action=>'show')
      #   r.match('/foo', :method=>:post).to(:action=>'create')
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

        behavior = Behavior.new(@proxy, @conditions.merge(conditions), @params, @defaults, @identifiers, @options)
        with_behavior_context(behavior, &block)
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

        behavior = Behavior.new(@proxy, @conditions, @params.merge(params), @defaults, @identifiers, @options)
        
        if block_given?
          with_behavior_context(behavior, &block)
        else
          behavior.to_route
        end
      end
      
      alias_method :register, :to
      
      # Sets default values for route parameters. If no value for the key
      # can be extracted from the request, then the value provided here
      # will be used.
      #
      # ==== Parameters
      # defaults<Hash>::
      #   The route's default values.
      # &block::
      #   Optional block. A new Behavior object is yielded scoped with
      #   the current Behavior.
      # ---
      # @public
      def defaults(defaults = {}, &block)
        behavior = Behavior.new(@proxy, @conditions, @params, @defaults.merge(defaults), @identifiers, @options)
        with_behavior_context(behavior, &block)
      end
      
      # Sets various miscellaneous route options. The currently supported
      # options are as follow:
      # * :controller_prefix
      # * :name_prefix
      # * :identifier
      # ---
      # @public
      def options(opts = {}, &block)
        options = @options.dup

        opts.each_pair do |key, value|
          options[key] = (options[key] || []) + [value.freeze] if value
        end

        behavior = Behavior.new(@proxy, @conditions, @params, @defaults, @identifiers, options)
        with_behavior_context(behavior, &block)
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
      # ---
      # @public
      def namespace(name_or_path, opts = {}, &block)
        name = name_or_path.to_s # We don't want this modified ever
        path = opts.has_key?(:path) ? opts[:path] : name

        raise Error, "The route has already been committed. Further options cannot be specified" if @route

        # option keys could be nil
        opts[:controller_prefix] = name unless opts.has_key?(:controller_prefix)
        opts[:name_prefix]       = name unless opts.has_key?(:name_prefix)

        behavior = self
        behavior = behavior.match("/#{path}") unless path.nil? || path.empty?
        behavior.options(opts, &block)
      end
      
      # Configures how params are converted for routes
      # ---
      # @public
      def identify(identifiers = {}, &block)
        identifiers = if Hash === identifiers
          @identifiers.merge(identifiers)
        else
          { Object => identifiers }
        end
        
        behavior = Behavior.new(@proxy, @conditions, @params, @defaults, identifiers.freeze, @options)
        with_behavior_context(behavior, &block)
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
        to_route(params, &conditional_block)
      end
      
      # Names this route in Router. Name must be a Symbol.
      #
      # ==== Parameters
      # symbol<Symbol>:: The name of the route.
      #
      # ==== Raises
      # ArgumentError:: symbol is not a Symbol.
      def name(prefix, name = nil)
        unless name
          name, prefix = prefix, nil
        end
        
        if @route
          full_name = [prefix, @options[:name_prefix], name].flatten.compact.join('_')
          @route.name = full_name
          self
        else
          register.name(prefix, name)
        end
      end

      def full_name(name)
        if @route
          @route.name = name
          self
        else
          register.full_name(name)
        end
      end
      
      # ==== Parameters
      # enabled<Boolean>:: True enables fixation on the route.
      def fixatable(enable = true)
        @route.fixation = enable
        self
      end

      def redirect(url, permanent = true)
        raise Error, "The route has already been committed." if @route

        status = permanent ? 301 : 302
        @route = Route.new(@conditions, {:url => url.freeze, :status => status.freeze}, :redirects => true)
        @route.register
        self
      end
      
      # So that Router can have a default route
      # ---
      # @private
      def with_proxy(&block) #:nodoc:
        proxy = Proxy.new
        proxy.push Behavior.new(proxy, @conditions, @params, @defaults, @identifiers, @options)
        proxy.instance_eval(&block)
        proxy
      end
      
    protected
      
      def to_route(params = {}, &conditional_block)
        
        raise Error, "The route has already been committed." if @route

        params     = @params.merge(params)
        controller = params[:controller]

        if prefixes = @options[:controller_prefix]
          controller ||= ":controller"
          
          prefixes.reverse_each do |prefix|
            break if controller =~ %r{^/(.*)} && controller = $1
            controller = "#{prefix}/#{controller}"
          end
        end
        
        params.merge!(:controller => controller.to_s.gsub(%r{^/}, '')) if controller
        
        # Sorts the identifiers so that modules that are at the bottom of the
        # inheritance chain come first (more specific modules first). Object
        # should always be last.
        identifiers = @identifiers.sort { |(first,_),(sec,_)| first <=> sec || 1 }
        
        @route = Route.new(@conditions.dup, params, :defaults => @defaults.dup, :identifiers => identifiers, &conditional_block)
        @route.register
        self
      end

    private
    
      def stringify_condition_values
        @conditions.each do |key, value|
          unless value.nil? || Regexp === value || Array === value
            @conditions[key] = value.to_s
          end
        end
      end
    
      def with_behavior_context(behavior, &block)
        if block_given?
          @proxy.push(behavior)
          retval = yield(behavior)
          @proxy.pop
        end
        behavior
      end

      def merge_paths(path)
        [@conditions[:path], path.freeze].flatten.compact
      end

    end
  end
end