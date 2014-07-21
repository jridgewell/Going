describe Going do
  describe '.go' do
    it 'creates new thread' do
      expect(Thread).to receive(:new)
      Going.go
    end

    it 'passes args to thread' do
      args = [1, 2, 3]
      expect(Thread).to receive(:new).with(*args)
      Going.go(*args)
    end

    it 'passes block to thread' do
      block = proc {}
      expect(Thread).to receive(:new) do |&blk|
        expect(blk).to be(block)
      end
      Going.go(&block)
    end

    it 'returns thread' do
      thread = double
      expect(Thread).to receive(:new) { thread }
      expect(Going.go).to be(thread)
    end
  end
end
