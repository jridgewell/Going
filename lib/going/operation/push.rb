module Going
  class Push < Operation
    def complete
      super
      select_statement.complete(&on_complete)
    end

    def close
      super
      select_statement.secondary_complete { fail }
    end
  end
end
