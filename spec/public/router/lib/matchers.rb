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
        "Expected a nil route. Got #{target.inspect}."
      end

      def negative_failure_message
        "Expected not to get a nil route."
      end
    end

    def have_nil_route
      HaveNilRoute.new
    end
  end
end