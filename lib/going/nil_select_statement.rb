module Going
  class NilSelectStatement
    include Singleton

    def ==(other)
      false
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
  end
end
