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
        push = Push.new(message: obj, select_statement: select_statement, &on_complete)
        pushes << push

        pair_with_pop push

        select_statement.when_complete(push, pushes, &method(:remove_operation)) if select_statement?

        push.complete if under_capacity?
        push.signal if select_statement?
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

        pair_with_push pop

        select_statement.when_complete(pop, pops, &method(:remove_operation)) if select_statement?

        pop.signal if select_statement?
        pop.close if closed?

        pop.wait(mutex)

        throw :close if closed? && !select_statement? && pop.incomplete?
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
      pushes.each_with_index.any? do |push, index|
        if push.select_statement != select_statement && pop.complete(push)
          complete_next_push_now_that_channel_under_capacity
          pops.pop
          pushes.delete_at index
          true
        end
      end
    end

    def pair_with_pop(push)
      pops.each_with_index.any? do |pop, index|
        if pop.select_statement != select_statement && pop.complete(push)
          pushes.pop
          pops.delete_at index
          true
        end
      end
    end

    def remove_operation(operation, queue)
      synchronize do
        index = queue.index(operation)
        queue.delete_at index if index
      end
    end

    def complete_next_push_now_that_channel_under_capacity
      push = pushes[capacity]
      push.complete if push && push.incomplete?
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
