module Going
  class Pop < Operation
    def message=(message)
      @completed = true
      @message = message
    end
  end
end
