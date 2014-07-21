require 'thread'
require 'going/channel'
require 'going/version'

module Going
  #
  # Creates an async thread to run the block
  #
  def self.go(*args, &blk)
    Thread.new(*args, &blk)
  end
end
