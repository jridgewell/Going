require 'singleton'

module Going
  class SelectHelper
    include Singleton

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
  end
end
