module Going

  class SelectStatement
    extend BooleanAttrReader

    class << self
      def instance
        Thread.current[global_key]
      end

      def instance?
        !instance.nil?
      end

      def new_instance
        self.instance = new
      end

      def reset
        self.instance = nil
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
      @completed = false
      @mutex = Mutex.new
      @complete_mutex = Mutex.new
      @semaphore = ConditionVariable.new
      @when_completes = []

      @args = nil
      @on_complete = nil
    end

    def select(&blk)
      select_helper = SelectHelper.instance
      if blk.arity == 1
        yield select_helper
      else
        select_helper.instance_eval(&blk)
      end

      wait
      cleanup
      call_completion_block
    end

    def when_complete(*args, &callback)
      when_completes << proc { callback.call(*args) }
    end

    def complete(*args, &on_complete)
      complete_mutex.synchronize do
        if !completed?
          @args = args
          @on_complete = on_complete
          @completed = true
          @secondary_completed = true
          semaphore.signal
        end
      end
    end

    def secondary_complete(*args, &on_complete)
      complete_mutex.synchronize do
        if !secondary_completed?
          @args = args
          @on_complete = on_complete
          @secondary_completed = true
          semaphore.signal
        end
      end
    end

    def once(*args, &blk)
      mutex.synchronize do
        yield(*args) if block_given? && incomplete?
      end
    end

    private

    attr_reader :semaphore, :mutex, :complete_mutex, :when_completes
    attr_reader :on_complete, :args
    battr_reader :completed, :secondary_completed

    def wait
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
      completed? || secondary_completed?
    end

    def cleanup
      when_completes.each(&:call)
    end

    def call_completion_block
      on_complete.call(*args) if on_complete
    end
  end
end
