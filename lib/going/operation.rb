module Going
  class Operation
    extend BooleanAttrReader

    attr_accessor :message
    attr_reader :select_statement

    def initialize(opts = {}, &on_complete)
      @message = opts[:message]
      @select_statement = opts[:select_statement]
      @on_complete = on_complete

      @completed = false
      @closed = false
      @signaled = false

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

    private

    def wake?
      signaled? || completed? || closed?
    end

    attr_reader :semaphore, :on_complete
    battr_reader :signaled, :completed, :closed, :select_statement
  end
end
