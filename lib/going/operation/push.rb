module Going
  class Push < Operation
    def message
      @completed = true
      @message
    end
  end
end
