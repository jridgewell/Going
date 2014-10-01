module Going
  #
  # Helper methods to emulate Go's Select Cases.
  #
  class SelectHelper
    include Singleton

    #
    # A case statement that will succeed immediately.
    #
    def default(&blk)
      SelectStatement.instance.default(&blk)
    end

    #
    # A case statement that will succeed after +seconds+ seconds.
    #
    def timeout(seconds, &blk)
      Channel.new.tap do |ch|
        Going.go do
          sleep seconds
          ch.receive
        end
        ch.push(nil, &blk)
      end
    end
  end
end
