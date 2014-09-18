require 'thread'
require 'going/boolean_attr_reader'
require 'going/channel'
require 'going/operation'
require 'going/operation/pop'
require 'going/operation/push'
require 'going/version'

module Going
  #
  # Creates an async thread to run the block
  #
  def self.go(*args, &blk)
    Thread.new(*args, &blk)
  end
end
