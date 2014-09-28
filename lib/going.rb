require 'thread'
require 'singleton'

require 'going/boolean_attr_reader'
require 'going/channel'
require 'going/select_statement'
require 'going/nil_select_statement'
require 'going/select_helper'
require 'going/operation'
require 'going/operation/shift'
require 'going/operation/push'
require 'going/version'

module Going
  #
  # Creates an async thread to run the block
  #
  def self.go(*args, &blk)
    Thread.new(*args, &blk)
  end

  #
  # Creates a synchronous block that will select the first
  # channel operation to complete. Only one operation inside
  # the block will complete and any operations that are
  # incomplete will be removed afterwards.
  #
  def self.select(&blk)
    fail 'a block must be passed' unless block_given?
    select = SelectStatement.new_instance
    select.select(&blk)
    SelectStatement.reset
  end
end
