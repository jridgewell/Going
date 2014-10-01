module Going
  #
  # This class represents message channels of specified capacity.
  # The push operation may be blocked if the capacity is full.
  # The shift operation may be blocked if no messages have been sent.
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
      @shifts = []

      @mutex = Mutex.new

      if block_given?
        Going.go do
          yield self
          close
        end
      end
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

        shifts.each(&:close).clear
        pushes_over_capacity!.each(&:close)
        @closed = true
      end
    end

    #
    # Pushes +obj+ to the channel. If the channel is already full, waits
    # until a thread shifts from it.
    #
    def push(obj, &on_complete)
      synchronize do
        push = Push.new(message: obj, select_statement: select_statement, &on_complete)
        pushes << push

        pair_with_shift push

        select_statement.cleanup(push) { remove_push push } if select_statement?

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
    def shift(&on_complete)
      synchronize do
        shift = Shift.new(select_statement: select_statement, &on_complete)
        shifts << shift

        pair_with_push shift

        select_statement.cleanup(shift) { remove_shift shift } if select_statement?

        shift.signal if select_statement?
        shift.close if closed?

        shift.wait(mutex)

        fail StopIteration, 'channel closed' if closed? && !select_statement? && shift.incomplete?
        shift.message
      end
    end

    #
    # Alias of shift
    #
    alias_method :receive, :shift
    alias_method :next, :shift

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

    #
    # Calls the given block once for each message until the channel is closed,
    # passing that message as a parameter.
    #
    # Note that this is a destructive action, since each message is `shift`ed.
    #
    def each
      return enum_for(:each) unless block_given?

      loop do
        yield self.shift
      end
    end

    def inspect
      inspection = [:capacity, :size].map do |attr|
        "#{attr}: #{send(attr).inspect}"
      end
      "#<#{self.class} #{inspection.join(', ')}>"
    end

    private

    attr_reader :mutex, :pushes, :shifts

    def synchronize(&blk)
      mutex.synchronize(&blk)
    end

    def pair_with_push(shift)
      pushes.each_with_index.any? do |push, index|
        if shift.complete(push)
          shifts.pop
          pushes.delete_at index
          complete_pushes_up_to_capacity
        end
      end
    end

    def pair_with_shift(push)
      shifts.each_with_index.any? do |shift, index|
        if shift.complete(push)
          pushes.pop
          shifts.delete_at index
        end
      end
    end

    def remove_shift(shift)
      synchronize do
        index = shifts.index(shift)
        shifts.delete_at index if index
      end
    end

    def remove_push(push)
      synchronize do
        index = pushes.index(push)
        pushes.delete_at index if index
        complete_pushes_up_to_capacity
      end
    end

    def complete_pushes_up_to_capacity
      pushes_up_to_capacity = pushes[0, capacity] || []
      pushes_up_to_capacity.select(&:incomplete?).each(&:complete)
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
