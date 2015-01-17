module Going
  class Operation
    extend BooleanAttrReader

    attr_reader :message, :select_statement

    def initialize(message: nil, on_complete: nil, select_statement: nil)
      @message = message
      @on_complete = on_complete
      @select_statement = select_statement

      @semaphore = ConditionVariable.new
    end

    def wait(mutex)
      semaphore.wait(mutex) until wake?
    end

    def signal
      @signaled = true
      semaphore.signal
    end

    def complete
      @completed = true
      signal
    end

    def close
      @closed = true
      signal
    end

    def incomplete?
      !completed?
    end

    def inspect
      "#<#{self.class} message: #{message.inspect}>"
    end

    private

    def wake?
      signaled? || completed? || closed?
    end

    attr_reader :semaphore, :on_complete
    battr_reader :signaled, :completed, :closed, :select_statement
  end
end
