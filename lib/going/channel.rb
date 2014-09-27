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

        pops.each(&:close).clear
        pushes_over_capacity!.each(&:close)
        @closed = true
      end
    end

    #
    # Pushes +obj+ to the channel. If the channel is already full, waits
    # until a thread pops from it.
    #
    def push(obj, &on_complete)
      synchronize do
        push = Push.new(obj, select_statement: select_statement, &on_complete)
        pushes << push

        if pop_index = pops.index { |x| select_statement != x.select_statement }
          if select_statement?
            select_statement.once(push, pop_index, &method(:pair_with_pop))
            select_statement.register(push, pushes)
          else
            pair_with_pop(push, pop_index)
          end
        end

        push.complete if under_capacity?
        push.signal if closed? || select_statement?
        push.close if closed?

        push.wait(mutex)

        fail 'cannot push to a closed channel' if closed? && !select_statement?
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
    def pop(&on_complete)
      synchronize do
        pop = Pop.new(select_statement: select_statement, &on_complete)
        pops << pop

        if push_index = pushes.index { |x| select_statement != x.select_statement }
          if select_statement?
            select_statement.once(pop, push_index, &method(:pair_with_push))
            select_statement.register(pop, pops)
          else
            pair_with_push(pop, push_index)
          end
        end

        pop.signal if pushes.any? || closed? || select_statement?
        pop.close if closed?
        pop.wait(mutex)

        throw :close if closed? && pop.incomplete? && !select_statement?
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

    def pair_with_push(pop, push_index)
      push = pushes[push_index]
      pop.message = push.message
      push.complete
      pop.complete
      signal_channel_now_under_capacity

      pops.pop
      pushes.delete_at push_index
    end

    def pair_with_pop(push, pop_index)
      pop = pops[pop_index]
      pop.message = push.message
      push.complete
      pop.complete

      pushes.pop
      pops.delete_at pop_index
    end

    def signal_channel_now_under_capacity
      if push = pushes[capacity]
        push.signal
      end
    end

    def pushes_over_capacity!
      pushes.slice!(capacity, pushes.size) || []
    end

    def under_capacity?
      pushes.size <= capacity
    end

    def select_statement
      SelectStatement.instance || NilSelectStatement.instance
    end

    def select_statement?
      SelectStatement.instance?
    end
  end
end
