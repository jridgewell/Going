class Spy
  attr_reader :args

  def initialize
    @called = false
    @args = nil
  end

  def call(*args)
    @called = true
    @args = args
  end

  def called?
    !!@called
  end

  def to_proc
    method(:call).to_proc
  end
end

