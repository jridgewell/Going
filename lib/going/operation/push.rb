module Going
  class Push < Operation
    def complete
      super
      select_statement.complete(&on_complete) if select_statement?
    end

    def close
      super
      select_statement.secondary_complete { fail } if select_statement?
    end
  end
end
