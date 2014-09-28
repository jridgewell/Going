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

        if pop_index = pops.index { |x| select_statement != x.select_statement }
          pair_with_pop(push, pop_index)
        end
        select_statement.when_complete(push, &method(:remove_push)) if select_statement?

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
          pair_with_push(pop, push_index)
        end
        select_statement.when_complete(pop, &method(:remove_pop)) if select_statement?

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

      if pop.complete(push)
        complete_push_now_channel_under_capacity
        pops.pop
        pushes.delete_at push_index
      end
    end

    def pair_with_pop(push, pop_index)
      pop = pops[pop_index]

      if pop.complete(push)
        pushes.pop
        pops.delete_at pop_index
      end
    end

    def remove_pop(pop)
      synchronize do
        index = pops.index(pop)
        pops.delete_at index if index
      end
    end

    def remove_push(push)
      synchronize do
        index = pushes.index(push)
        pushes.delete_at index if index
      end
    end

    def complete_push_now_channel_under_capacity
      if push = pushes[capacity]
        push.complete
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
