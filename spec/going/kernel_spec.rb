require 'going/kernel'

describe Kernel do
  describe '#go' do
    it 'delegates to Going.go' do
      expect(Going).to receive(:go)
      go
    end

    it 'passes args to Going.go' do
      expect(Going).to receive(:go).with(1, 2, 3)
      go(1, 2, 3)
    end

    it 'passes block to Going.go' do
      blk = proc {}
      expect(Going).to receive(:go) do |&block|
        expect(block).to be(blk)
      end
      go(&blk)
    end

    it "returns Going.go's return value" do
      thread = double
      expect(Going).to receive(:go) { thread }
      expect(go).to be(thread)
    end
  end

  describe '#select' do
    it 'delegates to Going.select' do
      expect(Going).to receive(:select)
      select
    end

    it 'passes block to Going.go' do
      blk = proc {}
      expect(Going).to receive(:select) do |&block|
        expect(block).to be(blk)
      end
      select(&blk)
    end
  end
end
