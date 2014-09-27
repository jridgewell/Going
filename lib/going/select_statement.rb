require 'singleton'

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
      @operations = []

      @args = nil
      @on_complete = nil
      @secondary_args = nil
      @secondary_complete = nil
    end

    def default(&blk)
      Channel.new(1) do |ch|
        ch.push(nil, &blk)
      end
    end

    def timeout(seconds, &blk)
      Channel.new do |ch|
        Going.go do
          sleep seconds
          ch.receive
        end
        ch.push(nil, &blk)
      end
    end


    # TODO: Separate these into another class
    def select(&blk)
      if blk.arity == 1
        yield self
      else
        instance_eval(&blk)
      end

      wait
      if completed?
        @on_complete.call(*@args) if @on_complete
      elsif secondary_completed?
        @secondary_complete.call(*@secondary_args) if @secondary_complete
      end
    end

    # TODO: Separate these into another class
    def complete(*args, &on_complete)
      complete_mutex.synchronize do
        unless completed?
          @args = args
          @on_complete = on_complete
          @completed = true
          semaphore.signal
        end
      end
    end

    # TODO: Separate these into another class
    def secondary_complete(*args, &on_complete)
      complete_mutex.synchronize do
        if incomplete? && !secondary_completed?
          @secondary_args = args
          @secondary_complete = on_complete
          @secondary_completed = true
          semaphore.signal
        end
      end
    end

    # TODO: Separate these into another class
    def once(*args, &blk)
      synchronize do
        yield(*args) if block_given? && incomplete?
      end
    end

    # TODO: Separate these into another class
    def register(operation, queue)
      @operations << { operation: operation, queue: queue }
    end

    private

    attr_reader :semaphore, :mutex, :complete_mutex
    battr_reader :completed, :secondary_completed

    def incomplete?
      !completed?
    end

    def synchronize(&blk)
      mutex.synchronize(&blk)
    end

    def wait
      synchronize do
        semaphore.wait(mutex) until wake?
      end
    end

    def wake?
      completed? || secondary_completed?
    end
  end

  class NilSelectStatement
    include Singleton

    def !=(other)
      true
    end

    def !
      true
    end

    def nil?
      true
    end
  end

end
