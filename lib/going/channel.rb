require 'going'

module Going
  #
  # This class represents message channels of specified capacity.
  # The push operation may be blocked if the capacity is full.
  # The pop operation may be blocked if no messages have been sent.
  #
  class Channel
    extend Forwardable

    #
    # Creates a fixed-length channel with a capacity of +capacity+.
    #
    def initialize(capacity = 0)
      fail ArgumentError, 'channel capacity must be 0 or greater' unless capacity >= 0
      @capacity = capacity
      @closed = false
      @mutex = Mutex.new
      @push_semaphore = ConditionVariable.new
      @pop_semaphore = ConditionVariable.new

      yield self if block_given?
    end

    #
    # Returns the capacity of the channel.
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
        messages.push obj
        signal_push
        wait_for_pop if messages.length > capacity
        self
      end
    end

    #
    # Alias of push
    #
    alias_method :<<, :push
    alias_method :yield, :push

    #
    # Receives data from the channel. If the channel is already empty,
    # waits until a thread pushes to it.
    #
    def pop
      synchronize do
        wait_for_push if messages.empty?
        signal_pop
        messages.shift
      end
    end

    #
    # Alias of pop
    #
    alias_method :receive, :pop
    alias_method :next, :pop

    #
    # Delegate size, length, and empty? to the messages queue
    #
    def_delegators :messages, :size, :empty?

    #
    # Alias of size
    #
    alias_method :length, :size

    def inspect
      inspection = [:capacity, :messages].map do |attr|
        "#{attr}: #{send(attr).inspect}"
      end
      "#<#{self.class} #{inspection.join(', ')}>"
    end

    private

    def_delegators :@mutex, :synchronize

    def messages
      @messages ||= []
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
