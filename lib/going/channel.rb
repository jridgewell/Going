require 'going'

module Going
  #
  # This class represents queues of specified size capacity.  The push operation
  # may be blocked if the capacity is full.
  #
  # See Queue for an example of how a SizedQueue works.
  #
  class Channel
    extend Forwardable

    #
    # Creates a fixed-length queue with a capacity of +capacity+.
    #
    def initialize(capacity = 0)
      fail ArgumentError, 'channel capacity must be 0 or greater' unless capacity >= 0
      @capacity = capacity
      @closed = false
      @mutex = Mutex.new
      @push_semaphore = ConditionVariable.new
      @pop_semaphore = ConditionVariable.new
    end

    #
    # Returns the capacity of the queue.
    #
    attr_reader :capacity

    #
    # Returns whether or not the channel is closed.
    #
    def closed?
      @closed
    end

    #
    # Closes the channel. Any data in the buffer may still be retrieved.
    #
    def close
      synchronize do
        closed? ? false : @closed = true
      end
    end

    #
    # Pushes +obj+ to the channel. If the channel is already full, waits
    # until a thread pops from it.
    #
    def push(obj)
      synchronize do
        fail 'cannot push to a closed channel' if closed?
        queue.push obj
        signal_push
        wait_for_pop if queue.length > capacity
        self
      end
    end

    #
    # Alias of push
    #
    alias_method :<<, :push

    #
    # Receives data from the channel. If the channel is already empty,
    # waits until a thread pushes to it.
    #
    def pop
      synchronize do
        wait_for_push if queue.empty?
        signal_pop
        queue.shift
      end
    end

    #
    # Alias of pop
    #
    alias_method :receive, :pop

    #
    # Delegate size, length, and empty? to the queue
    #
    def_delegators :queue, :size, :empty?

    #
    # Alias of size
    #
    alias_method :length, :size

    private

    def_delegators :@mutex, :synchronize

    def queue
      @queue ||= []
    end

    def signal_pop
      @push_semaphore.signal
    end

    def wait_for_pop
      @push_semaphore.wait(@mutex)
    end

    def signal_push
      @pop_semaphore.signal
    end

    def wait_for_push
      @pop_semaphore.wait(@mutex)
    end
  end
end
