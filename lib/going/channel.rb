require 'going'

module Going
  #
  # This class represents message channels of specified capacity.
  # The push operation may be blocked if the capacity is full.
  # The pop operation may be blocked if no messages have been sent.
  #
  class Channel
    #
    # Creates a fixed-length channel with a capacity of +capacity+.
    #
    def initialize(capacity = 0)
      fail ArgumentError, 'channel capacity must be 0 or greater' if capacity < 0
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
        return false if closed?
        @messages = messages.first(capacity)
        broadcast_close
        @closed = true
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
        wait_for_pop if size > capacity
        throw :close if closed?
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
        return if closed?
        wait_for_push if empty?
        signal_pop
        throw :close if closed?
        messages.shift
      end
    end

    #
    # Alias of pop
    #
    alias_method :receive, :pop
    alias_method :next, :pop

    #
    # Returns the number of messages in the channel
    #
    def size
      messages.size
    end
    
    #
    # Alias of size
    #
    alias_method :length, :size

    #
    # Returns whether the channel is empty.
    #
    def empty?
      messages.empty?
    end

    def inspect
      inspection = [:capacity, :messages].map do |attr|
        "#{attr}: #{send(attr).inspect}"
      end
      "#<#{self.class} #{inspection.join(', ')}>"
    end

    private

    def synchronize(&blk)
      @mutex.synchronize(&blk)
    end

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

    def broadcast_close
      @push_semaphore.broadcast
      @pop_semaphore.broadcast
    end
  end
end
