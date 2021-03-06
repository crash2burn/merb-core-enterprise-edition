require 'merb-core/dispatch/session/container'
require 'merb-core/dispatch/session/store_container'

module Merb
  class Config
    # Returns stores list constructed from
    # configured session stores (:session_stores config option)
    # or default one (:session_store config option).
    def self.session_stores
      @session_stores ||= begin
        config_stores = Array(
          Merb::Config[:session_stores] || Merb::Config[:session_store]
        )
        config_stores.map { |name| name.to_sym }
      end
    end
  end # Config

  # The Merb::Session module gets mixed into Merb::SessionContainer to allow
  # app-level functionality (usually found in app/models/merb/session.rb) for
  # session.
  #
  # You can use this module to implement additional methods to simplify
  # building wizard-like application components,
  # authentication frameworks, etc.
  module Session
  end

  # This is mixed into Merb::Controller on framework boot.
  module SessionMixin
    # Raised when no suitable session store has been setup.
    class NoSessionContainer < StandardError; end

    # Raised when storing more data than the available space reserved.
    class SessionOverflow < StandardError; end

    # Session configuration options:
    #
    # :session_id_key           The key by which a session value/id is
    #                           retrieved; defaults to _session_id
    #
    # :session_expiry           When to expire the session cookie;
    #                           defaults to 2 weeks
    #
    # :session_secret_key       A secret string which is used to sign/validate
    #                           session data; min. 16 chars
    #
    # :default_cookie_domain    The default domain to write cookies for.
    def self.included(base)
      # Register a callback to finalize sessions - needs to run before the cookie
      # callback extracts Set-Cookie headers from request.cookies.
      base._after_dispatch_callbacks.unshift lambda { |c| c.request.finalize_session }
    end

    # ==== Parameters
    # session_store<String>:: The type of session store to access.
    #
    # ==== Returns
    # SessionContainer:: The session that was extracted from the request object.
    def session(session_store = nil)
      request.session(session_store)
    end

    # Module methods

    # ==== Returns
    # String:: A random 32 character string for use as a unique session ID.
    def rand_uuid
      values = [
        rand(0x0010000),
        rand(0x0010000),
        rand(0x0010000),
        rand(0x0010000),
        rand(0x0010000),
        rand(0x1000000),
        rand(0x1000000),
      ]
      "%04x%04x%04x%04x%04x%06x%06x" % values
    end

    # Marks this session as needing a new cookie.
    def needs_new_cookie!
      @_new_cookie = true
    end

    def needs_new_cookie?
      @_new_cookie
    end

    module_function :rand_uuid, :needs_new_cookie!, :needs_new_cookie?

    module RequestMixin

      def self.included(base)
        base.extend ClassMethods

        # Keep track of all known session store types.
        base.cattr_accessor :registered_session_types
        base.registered_session_types = Dictionary.new
        base.class_inheritable_accessor :_session_id_key, :_session_secret_key,
                                        :_session_expiry

        base._session_id_key        = Merb::Config[:session_id_key] || '_session_id'
        base._session_expiry        = Merb::Config[:session_expiry] || Merb::Const::WEEK * 2
        base._session_secret_key    = Merb::Config[:session_secret_key]
      end

      module ClassMethods

        # ==== Parameters
        # name<~to_sym>:: Name of the session type to register.
        # class_name<String>:: The corresponding class name.
        #
        # === Notres
        # This is automatically called when Merb::SessionContainer is subclassed.
        def register_session_type(name, class_name)
          self.registered_session_types[name.to_sym] = class_name
        end

      end

      # The default session store type.
      def default_session_store
        Merb::Config[:session_store] && Merb::Config[:session_store].to_sym
      end

      # ==== Returns
      # Hash:: All active session stores by type.
      def session_stores
        @session_stores ||= {}
      end

      # Returns session container. Merb is able to handle multiple session
      # stores, hence a parameter to pick it.
      #
      # ==== Parameters
      # session_store<String>:: The type of session store to access,
      # defaults to default_session_store.
      #
      # === Notes
      # If no suitable session store type is given, it defaults to
      # cookie-based sessions.
      def session(session_store = nil)
        session_store ||= default_session_store
        if class_name = self.class.registered_session_types[session_store]
          session_stores[session_store] ||= Object.full_const_get(class_name).setup(self)
        elsif fallback = self.class.registered_session_types.keys.first
          Merb.logger.warn "Session store '#{session_store}' not found. Check your configuration in init file."
          Merb.logger.warn "Falling back to #{fallback} session store."
          session(fallback)
        else
          msg = "No session store set. Set it in init file like this: c[:session_store] = 'activerecord'"
          Merb.logger.error!(msg)
          raise NoSessionContainer, msg
            
        end
      end

      # ==== Parameters
      # new_session<Merb::SessionContainer>:: A session store instance.
      #
      # === Notes
      # The session is assigned internally by its session_store_type key.
      def session=(new_session)
        if self.session?(new_session.class.session_store_type)
          original_session_id = self.session(new_session.class.session_store_type).session_id
          if new_session.session_id != original_session_id
            set_session_id_cookie(new_session.session_id)
          end
        end
        session_stores[new_session.class.session_store_type] = new_session
      end

      # Whether a session has been setup
      def session?(session_store = nil)
        (session_store ? [session_store] : session_stores).any? do |type, store|
          store.is_a?(Merb::SessionContainer)
        end
      end

      # Teardown and/or persist the current sessions.
      def finalize_session
        session_stores.each { |name, store| store.finalize(self) }
      end
      alias :finalize_sessions :finalize_session

      # Assign default cookie values
      def default_cookies
        defaults = {}
        if route && route.allow_fixation? && params.key?(_session_id_key)
          Merb.logger.info("Fixated session id: #{_session_id_key}")
          defaults[_session_id_key] = params[_session_id_key]
        end
        defaults
      end

      # Sets session cookie value. Used by Cookie session store.
      #
      # ==== Parameters
      # value<String>:: The value of the session cookie; either the session id or the actual encoded data.
      def set_session_cookie_value(value)
        cookies.set_cookie(_session_id_key, value, { :expired => Time.now + _session_expiry })
      end
      alias :set_session_id_cookie :set_session_cookie_value

      # ==== Returns
      # String:: The value of the session cookie; either the session id or the actual encoded data.
      def session_cookie_value
        cookies[_session_id_key]
      end
      alias :session_id :session_cookie_value
    end
  end
end
