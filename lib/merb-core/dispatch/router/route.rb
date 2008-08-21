module Merb

  class Router
    # This entire class is private and should never be accessed outside of
    # Merb::Router and Behavior
    class Route
      SEGMENT_REGEXP               = /(:([a-z_][a-z0-9_]+))/
      OPTIONAL_SEGMENT_REGEX       = /^.*?([\(\)])/i
      SEGMENT_REGEXP_WITH_BRACKETS = /(:[a-z_]+)(\[(\d+)\])?/
      JUST_BRACKETS                = /\[(\d+)\]/
      SEGMENT_CHARACTERS           = "[^\/.,;?]".freeze

      attr_reader :conditions
      attr_reader :params, :segments, :index, :symbol
      attr_reader :redirect_status, :redirect_url

      def initialize(conditions, params, options = {}, &conditional_block)
        @conditions, @params = conditions, params

        if options[:redirects]
          @redirects         = true
          @redirect_status   = @params[:status]
          @redirect_url      = @params[:url]
          @defaults          = {}
        else
          @defaults          = options[:defaults] || {}
          @conditional_block = conditional_block
        end

        @segments          = []
        @symbol_conditions = {}
        @placeholders      = {}
        @fixation          = false
        compile
      end

      def regexp?
        @regexp
      end

      def allow_fixation?
        @fixation
      end

      def fixatable(enable = true)
        @fixation = enable
        self
      end

      def redirects?
        @redirects
      end

      def register
        @index = Merb::Router.routes.size
        Merb::Router.routes << self
        self
      end

      def name(symbol)
        raise ArgumentError.new("Route names must be symbols") unless Symbol === (@symbol = symbol)
        Merb::Router.named_routes[@symbol] = self
      end
      
      def variables
        @variables ||= @segments.flatten.select { |s| Hash === s }
      end

      # This is a temporary implementation to get the specs to pass
      def generate(params = {})
        raise GenerationError, "Cannot generate regexp Routes" if regexp?
        query_params = params.dup
        # Generate the path part of the URL from the segments
        if url = segment_group_to_string(segments, params, query_params, true)
          # Query params
          query_params.delete_if { |key, value| value.nil? }
          unless query_params.empty?
            url << "?" + Merb::Request.params_to_query_string(query_params)
          end

          return url
        end
      end

      def compiled_statement(first = false)
        els_if = first ? '  if ' : '  elsif '

        code = ""
        code << els_if << condition_statements.join(" && ") << "\n"
        if @conditional_block
          code << "    [#{@index.inspect}, block_result]" << "\n"
        else
          code << "    [#{@index.inspect}, #{params_as_string}]" << "\n"
        end
      end

    private

    # === Generation ===

      # Checks if the supplied parameters are sufficient to generate the supplied
      # segment group. Before an optional segment group is generated, it must be
      # verified that the group can be generated with the supplied parameters.
      # ===
      # TODO: Yeah, this is temporary and needs to be completely redone (after the specs pass)
      def matches_segment_group?(group, params = {})
        group.all? do |segment|
          # params[segment] &&
          #   (@symbol_conditions[segment].nil? || @symbol_conditions[segment] =~ params[segment])
          condition = @symbol_conditions[segment]
          param = params[segment]
          param && (condition.nil? || (condition.is_a?(String) ? condition == param : condition =~ param))
        end
      end

      # Everytime that a param is used to generate a segment, the key should be be
      # deleted from query_params. This is so that they query params part of the
      # URL can be generated at the end.
      # ===
      # TODO: Yeah, this is temporary and needs to be completely redone (after the specs pass)
      def segment_group_to_string(group, params = {}, query_params = {}, validate = false)
        if validate && !matches_segment_group?(group.select { |s| Symbol === s }, params)
          return nil
        end

        group.map do |segment|
          if Array === segment
            # if the array is entirely Strings, then don't generate it. Originally
            # I generated the extra bit, but it turned out to be ugly when it came
            # to generating resource routes (it would append /index to the collection
            # index route).
            segment_group_to_string(segment, params, query_params, true) unless
              segment.all? { |s| String === s }
          elsif Symbol === segment
            query_params.delete(segment)
            value = params[segment]
            # --- Pretty much a carry over from the old router ---
            value.respond_to?(:to_param) ? value.to_param : value.to_s
          else
            segment
          end
        end.join
      end
      
      # The old bit that converted objects for the segment
      # ---
      # value =
      #   if segment.is_a? Symbol
      #     if params.is_a? Hash
      #       if segment.to_s =~ /_id/ && params[:id].respond_to?(segment)
      #         params[segment] = params[:id].send(segment)
      #       end
      #       query_params.delete segment
      #       params[segment] || fallback[segment]
      #     else
      #       if segment == :id && params.respond_to?(:to_param)
      #         params.to_param
      #       elsif segment == :id && params.is_a?(Fixnum)
      #         params
      #       elsif params.respond_to?(segment)
      #         params.send(segment)
      #       else
      #         fallback[segment]
      #       end
      #     end
      #   elsif segment.respond_to? :to_s
      #     segment
      #   else
      #     raise "Segment type '#{segment.class}' can't be converted to a string"
      #   end
      # (value.respond_to?(:to_param) ? value.to_param : value).to_s.unescape_regexp

    # === Compilation ===

      def compile
        compile_conditions
        compile_params
      end

      def compile_conditions
        @original_conditions = conditions.dup

        if path = conditions[:path]
          path = [path].flatten.compact
          if path = compile_path(path)
            conditions[:path] = Regexp.new("^#{path}$")
          else
            conditions.delete(:path)
          end
        end

        # conditions.each do |key, value|
        #   unless Regexp === value
        #     conditions[key] = Regexp.new("^#{Regexp.escape(value)}$")
        #   end
        # end
      end

      # The path is passed in as an array of different parts. We basically have
      # to concat all the parts together, then parse the path and extract the
      # variables. However, if any of the parts are a regular expression, then
      # we abort the parsing and just convert it to a regexp.
      def compile_path(path)
        @segments = []
        compiled  = ""

        return nil if path.nil? || path.empty?

        path.each do |part|
          if Regexp === part
            @regexp   = true
            @segments = []
            compiled << part.source.sub(/^\^/, '').sub(/\$$/, '')
          elsif String === part
            segments = segments_with_optionals_from_string(part.dup)
            compile_path_segments(compiled, segments)
            # Concat the segments
            unless regexp?
              if String === @segments[-1] && String === segments[0]
                @segments[-1] << segments.shift
              end
              @segments.concat segments
            end
          else
            raise ArgumentError.new("A route path can only be specified as a String or Regexp")
          end
        end

        compiled
      end

      # Simple nested parenthesis parser
      def segments_with_optionals_from_string(path, nest_level = 0)
        segments = []

        # Extract all the segments at this parenthesis level
        while segment = path.slice!(OPTIONAL_SEGMENT_REGEX)
          # Append the segments that we came across so far
          # at this level
          segments.concat segments_from_string(segment[0..-2]) if segment.length > 1
          # If the parenthesis that we came across is an opening
          # then we need to jump to the higher level
          if segment[-1,1] == '('
            segments << segments_with_optionals_from_string(path, nest_level + 1)
          else
            # Throw an error if we can't actually go back down (aka syntax error)
            raise "There are too many closing parentheses" if nest_level == 0
            return segments
          end
        end

        # Save any last bit of the string that didn't match the original regex
        segments.concat segments_from_string(path) unless path.empty?

        # Throw an error if the string should not actually be done (aka syntax error)
        raise "You have too many opening parentheses" unless nest_level == 0

        segments
      end

      def segments_from_string(path)
        segments = []

        while match = (path.match(SEGMENT_REGEXP))
          segments << match.pre_match unless match.pre_match.empty?
          segments << match[2].intern
          path = match.post_match
        end

        segments << path unless path.empty?
        segments
      end

      def compile_path_segments(compiled, segments)
        segments.each do |segment|
          if String === segment
            compiled << Regexp.escape(segment)
          elsif Symbol === segment
            condition = (@symbol_conditions[segment] ||= @conditions.delete(segment))
            compiled << compile_segment_condition(condition)
            # Create a param for the Symbol segment if none already exists
            @params[segment] = "#{segment.inspect}" unless @params.has_key?(segment)
            @placeholders[segment] ||= capturing_parentheses_count(compiled)
          elsif Array === segment
            compiled << "(?:"
            compile_path_segments(compiled, segment)
            compiled << ")?"
          else
            raise ArgumentError, "conditions[:path] segments can only be a Strings, Symbols, or Arrays"
          end
        end
      end

      # Handles anchors in Regexp conditions
      def compile_segment_condition(condition)
        return "(#{SEGMENT_CHARACTERS}+)" unless condition
        return "(#{condition})"           unless Regexp === condition

        condition = condition.source
        # Handle the start anchor
        condition = if condition =~ /^\^/
          condition[1..-1]
        else
          "#{SEGMENT_CHARACTERS}*#{condition}"
        end
        # Handle the end anchor
        condition = if condition =~ /\$$/
          condition[0..-2]
        else
          "#{condition}#{SEGMENT_CHARACTERS}*"
        end

        "(#{condition})"
      end

      def compile_params
        # Loop through each param and compile it
        @defaults.merge(@params).each do |key, value|
          if value.nil?
            @params.delete(key)
          elsif String === value
            @params[key] = compile_param(value)
          else
            raise ArgumentError, "param value for #{key.to_s}  must be a string (#{value.inspect})"
          end
        end
      end

      # This was pretty much a copy / paste from the old router
      def compile_param(value)
        result = []
        match  = true
        while match
          if match = SEGMENT_REGEXP_WITH_BRACKETS.match(value)
            result << match.pre_match.inspect unless match.pre_match.empty?
            placeholder_key = match[1][1..-1].intern
            if match[2] # has brackets, e.g. :path[2]
              result << "#{placeholder_key}#{match[3]}"
            else # no brackets, e.g. a named placeholder such as :controller
              if place = @placeholders[placeholder_key]
                # result << "(path#{place} || )" # <- Defaults
                with_defaults  = ["(path#{place}"]
                with_defaults << " || #{@defaults[placeholder_key].inspect}" if @defaults[placeholder_key]
                with_defaults << ")"
                result << with_defaults.join
              else
                raise "Placeholder not found while compiling routes: #{placeholder_key.inspect}"
              end
            end
            value = match.post_match
          elsif match = JUST_BRACKETS.match(value)
            result << match.pre_match.inspect unless match.pre_match.empty?
            result << "path#{match[1]}"
            value = match.post_match
          else
            result << value.inspect unless value.empty?
          end
        end

        # array_to_code(result).gsub("\\_", "_")
        result.join(' + ').gsub("\\_", "_")
      end

    # ---------- Required Symbol segments ---------- 

      # Returns an array containing all the symbols that are required for
      # this route
      def required_symbols_from_segments
        segments.select { |segment| Symbol === segment }.uniq
      end

    # ---------- Route compilation ---------- 

      def condition_statements
        statements = []

        conditions.each_pair do |key, value|
          statements << if Regexp === value
            captures = ""

            if (max = capturing_parentheses_count(value)) > 0
              captures << (1..max).to_a.map { |n| "#{key}#{n}" }.join(", ")
              captures << " = "
              captures << (1..max).to_a.map { |n| "$#{n}" }.join(", ")
            end

            # Note: =~ is slightly faster than .match
            %{(#{value.inspect} =~ cached_#{key} #{' && ((' + captures + ') || true)' unless captures.empty?})}
          else
            %{(cached_#{key} == #{value.inspect})}
          end
        end

        if @conditional_block
          statements << "(block_result = #{CachedProc.new(@conditional_block)}.call(request, #{params_as_string}))"
        end

        statements
      end

      def params_as_string
        elements = params.keys.map do |k|
          "#{k.inspect} => #{params[k]}"
        end
        "{#{elements.join(', ')}}"
      end

    # ---------- Utilities ---------- 

      def capturing_parentheses_count(regexp)
        regexp = regexp.source if Regexp === regexp
        # regexp.scan(%r[\((?!\?)]).length
        regexp.scan(/(?!\\)[(](?!\?[#=:!>-imx])/).length
      end

      def array_to_code(arr)
        code = ''
        arr.each_with_index do |part, i|
          code << ' + ' if i > 0
          case part
          when Symbol
            code << part.to_s
          when String
            code << %{"#{part}"}
          else
            raise "Don't know how to compile array part: #{part.class} [#{i}]"
          end
        end
        code
      end
    end
  end  
end