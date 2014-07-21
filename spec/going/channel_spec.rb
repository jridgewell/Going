describe Going::Channel do
  subject(:channel) { Going::Channel.new }
  def elapsed_time(original_time)
    (Time.now - original_time)
  end

  describe '.new' do
    it 'defaults capacity to 0' do
      expect(channel.capacity).to eq(0)
    end

    it 'throws error if capacity is less than 0' do
      expect { Going::Channel.new(-1) }.to raise_error
    end

    it 'is not closed' do
      expect(channel).not_to be_closed
    end
  end

  describe '#capacity' do
    it 'returns capacity of channel' do
      channel = Going::Channel.new(5)
      expect(channel.capacity).to eq(5)
    end
  end

  describe '#close' do
    it 'closes channel' do
      channel.close
      expect(channel).to be_closed
    end

    it 'returns true after closing channel' do
      expect(channel.close).to be(true)
    end

    it 'returns false if channel already closed' do
      channel.close
      expect(channel.close).to be(false)
    end

    it 'will wake a blocked push' do
      Going.go do
        sleep 0.1
        channel.close
      end
      expect { channel.push 1 }.to throw_symbol(:close)
    end

    it 'will wake a blocked push' do
      Going.go do
        sleep 0.1
        channel.close
      end
      expect { channel.receive }.to throw_symbol(:close)
    end

    it 'will reject all but the first #capacity pushes' do
      channel = Going::Channel.new 2
      Going.go do
        sleep 0.1
        channel.close
      end
      catch :close do
        3.times { |i| channel.push i }
      end
      expect(channel.size).to eq(2)
    end
  end

  describe '#push' do
    subject(:channel) { Going::Channel.new 1 }

    it 'is aliased as #<<' do
      expect(channel.method(:<<)).to eq(channel.method(:push))
    end

    it 'raises error if channel is closed' do
      channel.close
      expect { channel.push 1 }.to raise_error
    end

    it 'will not block if channel is under capacity' do
      now = Time.now
      channel.push 1
      expect(elapsed_time(now)).to be < 1
    end

    it 'will block if channel is over capacity' do
      channel.push 1
      Going.go do
        sleep 0.25
        channel.receive
      end
      now = Time.now
      channel.push 1
      expect(elapsed_time(now)).to be > 0.2
    end

    it 'will push messages in order' do
      channel.push 1
      Going.go do
        channel.push 2
      end
      Going.go do
        sleep 0.05
        channel.push 3
      end
      sleep 0.1
      1.upto(3).each do |i|
        expect(channel.receive).to eq(i)
      end
    end

    it 'returns the channel' do
      expect(channel.push(1)).to be(channel)
    end
  end

  describe '#pop' do
    subject(:channel) { Going::Channel.new 1 }

    it 'is aliased as #receive' do
      expect(channel.method(:receive)).to eq(channel.method(:pop))
    end

    it 'returns the next message' do
      channel.push 1
      expect(channel.receive).to eq(1)
    end

    it 'will not block if channel is not empty' do
      channel.push 1
      now = Time.now
      channel.receive
      expect(elapsed_time(now)).to be < 1
    end

    it 'will block if channel is empty' do
      Going.go do
        sleep 0.25
        channel.push 1
      end
      now = Time.now
      channel.receive
      expect(elapsed_time(now)).to be > 0.2
    end

    it 'returns nil if closed' do
      channel.close
      expect(channel.receive).to be_nil
    end

    it 'does not block if closed' do
      channel.close
      now = Time.now
      channel.receive
      expect(elapsed_time(now)).to be < 1
    end
  end

  describe '#size' do
    it 'is aliased as #length' do
      expect(channel.method(:length)).to eq(channel.method(:size))
    end

    it 'returns the number of messages in channel' do
      channel = Going::Channel.new 2
      expect(channel.size).to eq(0)
      channel.push 1
      expect(channel.size).to eq(1)
      channel.push 1
      expect(channel.size).to eq(2)
      channel.receive
      expect(channel.size).to eq(1)
      channel.receive
      expect(channel.size).to eq(0)
    end
  end

  describe '#empty?' do
    it 'returns true when no messages in channel' do
      expect(channel).to be_empty
    end

    context 'when capacity is greater than 0' do
      subject(:channel) { Going::Channel.new 1 }

      it 'returns true when messages in channel' do
        expect(channel).to be_empty
      end

      it 'returns false when messages in channel' do
        channel.push 1
        expect(channel).not_to be_empty
      end
    end
  end
end
