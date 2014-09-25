require 'going'

describe Going::Channel do
  before(:all) do
    @abort_on_exception = Thread.abort_on_exception
    Thread.abort_on_exception = true
  end
  after(:all) do
    Thread.abort_on_exception = @abort_on_exception
  end
  before(:all) do
    @private_methods = [:pushes, :pops]
    @private_methods.each do |private_method|
      Going::Channel.class_eval { public private_method }
    end
  end
  after(:all) do
    @private_methods.each do |private_method|
      Going::Channel.class_eval { private private_method }
    end
  end

  subject(:channel) { Going::Channel.new }
  let(:buffered_channel) { Going::Channel.new 1 }

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

    it 'yields itself if block given' do
      yielded = nil
      channel = Going::Channel.new { |y| yielded = y }
      expect(yielded).to be(channel)
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
        sleep 0.1 until channel.pushes.size > 0
        channel.close
      end
      expect { channel.push 1 }.to raise_error
    end

    it 'will wake a blocked pop' do
      Going.go do
        sleep 0.1 until channel.pops.size > 0
        channel.close
      end
      expect { channel.receive }.to throw_symbol(:close)
    end

    it 'will reject all but the first #capacity pushes' do
      begin
        channel = Going::Channel.new 2
        Going.go do
          sleep 0.1 until channel.pushes.size > 2
          channel.close
        end
        3.times { |i| channel.push i }
      rescue
        expect(channel.size).to eq(2)
      end
    end
  end

  describe '#push' do
    it 'is aliased as #<<' do
      expect(channel.method(:<<)).to eq(channel.method(:push))
    end

    it 'is aliased as #yield' do
      expect(channel.method(:yield)).to eq(channel.method(:push))
    end

    it 'raises error if channel is closed' do
      channel.close
      expect { channel.push 1 }.to raise_error
    end

    it 'will not block if channel is under capacity' do
      now = Time.now
      buffered_channel.push 1
      expect(elapsed_time(now)).to be < 0.2
    end

    it 'will block if channel is over capacity' do
      Going.go do
        sleep 0.1 until channel.pushes.size > 0
        sleep 0.25
        channel.receive
      end
      now = Time.now
      channel.push 1
      expect(elapsed_time(now)).to be > 0.2
    end

    it 'will push messages in order' do
      buffered_channel.push 1
      Going.go do
        sleep 0.1 until buffered_channel.pushes.size > 0
        buffered_channel.push 2
      end
      Going.go do
        sleep 0.1 until buffered_channel.pushes.size > 1
        buffered_channel.push 3
      end
      sleep 0.1 until buffered_channel.pushes.size > 2
      1.upto(3).each do |i|
        expect(buffered_channel.receive).to eq(i)
      end
    end

    it 'returns the channel' do
      expect(buffered_channel.push(1)).to be(buffered_channel)
    end
  end

  describe '#pop' do
    it 'is aliased as #receive' do
      expect(channel.method(:receive)).to eq(channel.method(:pop))
    end

    it 'is aliased as #next' do
      expect(channel.method(:next)).to eq(channel.method(:pop))
    end

    it 'returns the next message' do
      buffered_channel.push 1
      expect(buffered_channel.receive).to eq(1)
    end

    it 'will not block if channel is not empty' do
      buffered_channel.push 1
      now = Time.now
      buffered_channel.receive
      expect(elapsed_time(now)).to be < 0.2
    end

    it 'will block if channel is empty' do
      Going.go do
        sleep 0.1 until channel.pops.size > 0
        sleep 0.25
        channel.push 1
      end
      now = Time.now
      channel.receive
      expect(elapsed_time(now)).to be > 0.2
    end

    it 'throws :close if channel is closed' do
      channel.close
      expect { channel.receive }.to throw_symbol(:close)
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

    it 'returns 0 for unbuffered channel' do
      Going.go do
        channel.push 1
      end
      sleep 0.1 until channel.pushes.size > 0
      expect(channel.size).to eq(0)
    end
  end

  describe '#empty?' do
    context 'when capacity is 0' do
      it 'returns true when no messages in channel' do
        expect(channel).to be_empty
      end

      it 'returns true even if blocked pushes' do
        Going.go do
          channel.push 1
        end
        sleep 0.1 until channel.pushes.size > 0
        expect(channel).to be_empty
      end
    end

    context 'when capacity is greater than 0' do
      it 'returns true when no messages in channel' do
        expect(buffered_channel).to be_empty
      end

      it 'returns false when messages in channel' do
        buffered_channel.push 1
        expect(buffered_channel).not_to be_empty
      end
    end
  end
end
