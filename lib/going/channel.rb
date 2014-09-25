module Going
  #
  # This class represents message channels of specified capacity.
  # The push operation may be blocked if the capacity is full.
  # The pop operation may be blocked if no messages have been sent.
  #
  class Channel
    extend BooleanAttrReader

    #
    # Creates a fixed-length channel with a capacity of +capacity+.
    #
    def initialize(capacity = 0)
      fail ArgumentError, 'channel capacity must be 0 or greater' if capacity < 0
      @capacity = capacity

      @pushes = []
      @pops = []

      @closed = false
      @mutex = Mutex.new

      yield self if block_given?
    end

    #
    # Returns the capacity of the channel.
    #
    attr_reader :capacity

    #
    # Returns whether or not the channel is closed.
    #
    battr_reader :closed

    #
    # Closes the channel. Any data in the buffer may still be retrieved.
    #
    def close
      synchronize do
        return false if closed?

        pops.each(&:signal).clear
        pushes.pop.signal while pushes.size > capacity
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
        push = Push.new(obj)

        pair_with_pop(push) or pushes << push
        push.wait(mutex) if pushes.size > capacity

        fail 'cannot push to a closed channel' if closed?
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
        throw :close if closed?
        pop = Pop.new

        pair_with_push(pop) or pops << pop
        pop.wait(mutex) if empty?

        throw :close if closed?
        pop.message
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
      [capacity, pushes.size].min
    end

    #
    # Alias of size
    #
    alias_method :length, :size

    #
    # Returns whether the channel is empty.
    #
    def empty?
      size == 0
    end

    def inspect
      inspection = [:capacity, :size].map do |attr|
        "#{attr}: #{send(attr).inspect}"
      end
      "#<#{self.class} #{inspection.join(', ')}>"
    end

    private

    attr_reader :mutex, :pushes, :pops

    def synchronize(&blk)
      mutex.synchronize(&blk)
    end

    def pair_with_push(pop)
      return unless push = pushes.shift
      pop.message = push.message
      pop.signal
      push.signal
      signal_channel_now_under_capacity
      true
    end

    def pair_with_pop(push)
      return unless pop = pops.shift
      pop.message = push.message
      push.signal
      pop.signal
      true
    end

    def signal_channel_now_under_capacity
      if capacity.nonzero? && push = pushes[capacity - 1]
        push.signal
      end
    end
  end
end
