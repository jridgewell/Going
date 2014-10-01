module Going
  class Shift < Operation
    def complete(push)
      return if push.select_statement == select_statement
      select_statement.once do
        push.select_statement.once do
          self.message = push.message

          super()
          push.complete
          notify_select_statement
          true
        end
      end
    end

    def close
      super
      notify_select_statement
    end

    private

    def notify_select_statement
      select_statement.complete(self, message, ok: ok?, &on_complete)
    end

    def ok?
      !closed?
    end
  end
end
