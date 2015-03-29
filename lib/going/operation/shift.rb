module Going
  class Shift < Operation
    def complete(push)
      return if push.select_statement === select_statement
      select_statement.once do
        push.select_statement.once do
          @message = push.message

          push.complete
          super()
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
      select_statement.complete(self, on_complete, message, ok: ok?)
    end

    def ok?
      !closed?
    end
  end
end
