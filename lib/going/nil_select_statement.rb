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

    def complete(*args)
    end

    def secondary_complete(*args)
    end
  end
end
