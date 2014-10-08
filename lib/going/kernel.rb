require 'going'

module Kernel
  def go(*args, &blk)
    Going.go(*args, &blk)
  end

  def select(&blk)
    Going.select(&blk)
  end
end
