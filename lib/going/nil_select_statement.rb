require 'singleton'

module Going
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

    def once
      yield
    end
  end
end
