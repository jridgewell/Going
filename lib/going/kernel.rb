require 'going'

module Kernel
  def go(*args, &blk)
    Going.go(*args, &blk)
  end
end
