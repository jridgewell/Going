module Going
  class Push < Operation
    def complete
      super
      select_statement.complete(self, &on_complete)
    end

    def close
      super
      select_statement.secondary_complete do
        fail 'cannot push to a closed channel'
      end
    end
  end
end
