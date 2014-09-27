module Going
  class Pop < Operation
    def complete
      super
      complete_select if select_statement?
    end

    def ok?
      !closed?
    end

    def close
      super
      complete_select if select_statement?
    end

    private

    def complete_select
      select_statement.complete(message, ok: ok?, &on_complete)
    end
  end
end
