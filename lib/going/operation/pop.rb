module Going
  class Pop < Operation
    def complete(push)
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
      select_statement.complete(message, ok: ok?, &on_complete)
    end

    def ok?
      !closed?
    end
  end
end
