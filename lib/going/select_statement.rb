module Going

  class SelectStatement
    extend BooleanAttrReader

    class << self
      def instance
        Thread.current[global_key] || reset
      end

      def instance?
        !instance.nil?
      end

      def new_instance
        self.instance = new
      end

      def reset
        self.instance = NilSelectStatement.instance
      end

      private

      def instance=(select_statement)
        Thread.current[global_key] = select_statement
      end

      def global_key
        @global_key ||= "Going_#{Going::SelectStatement.object_id}"
      end
    end

    def initialize
      @once_mutex = Mutex.new
      @complete_mutex = Mutex.new
      @semaphore = ConditionVariable.new
      @cleanups = {}
      @already_completed = []
    end

    def select(blk)
      select_helper = SelectHelper.instance
      if blk.arity == 1
        blk.call select_helper
      else
        select_helper.instance_eval(&blk)
      end

      already_completed.sample.call unless already_completed.empty?
      wait
    end

    def cleanup(operation, &callback)
      cleanups[operation] = callback
    end

    def cleanup!
      cleanups.values.each(&:call)
    end

    def complete(operation, on_complete, *args)
      complete_mutex.synchronize do
        if !completed?
          cleanups.delete operation
          @args = args
          @on_complete = on_complete
          @completed = true
          signal
        end
      end
    end

    def default(on_complete)
      complete_mutex.synchronize do
        fail 'multiple defaults in select' if defaulted?
        @defaulted = true
        if !completed?
          @on_complete = on_complete
        end
      end
    end

    def once(&blk)
      if waited?
        once_mutex.synchronize do
          yield(*args) if block_given? && incomplete?
        end
      else
        already_completed << blk
      end
    end

    def call_completion_block
      on_complete.call(*args) if on_complete
    end

    private

    attr_reader :semaphore, :once_mutex, :complete_mutex, :cleanups
    attr_reader :on_complete, :args, :already_completed
    battr_reader :completed, :defaulted, :waited

    def wait
      @waited = true
      complete_mutex.synchronize do
        semaphore.wait(complete_mutex) until wake?
      end
    end

    def incomplete?
      complete_mutex.synchronize do
        !completed?
      end
    end

    def wake?
      completed? || defaulted?
    end

    def signal
      semaphore.signal
    end
  end
end
