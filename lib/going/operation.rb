module Going
  class Operation
    extend BooleanAttrReader

    attr_accessor :message

    def initialize(message = nil)
      @message = message
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

    private

    def wake?
      signaled?
    end

    attr_reader :semaphore
    battr_reader :signaled

  end
end
