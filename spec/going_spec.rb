describe Going do
  describe '.go' do
    it 'creates new thread' do
      expect(Thread).to receive(:new)
      Going.go
    end

    it 'passes args to block' do
      args = nil
      Going.go(1, 2, 3) { |*a| args = a }.join
      expect(args).to eq([1, 2, 3])
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
