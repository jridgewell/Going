require 'going'

describe Going::Channel do
  subject(:channel) { Going::Channel.new }
  let(:buffered_channel) { Going::Channel.new 1 }

  def elapsed_time(original_time)
    (Time.now - original_time)
  end

  def sleeper(channel, queue, size)
    fail "channel does not respond to #{queue}" unless channel.respond_to? queue, true
    begin
      Thread.pass
      sleep 0.1
    end until channel.send(queue).size == size
    expect(channel.send(queue).size).to eq(size)
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

    context 'when passing a block' do
      it 'calls block asynchronously' do
        channel_is_nil = true
        channel = Going::Channel.new do |ch|
          channel_is_nil = channel.nil?
          ch.push 1
        end
        channel.receive
        expect(channel_is_nil).to be(false)
      end

      it 'yields self if block given' do
        yielded = nil
        channel = Going::Channel.new do |ch|
          yielded = ch
          ch.push 1
        end
        channel.receive
        expect(yielded).to be(channel)
      end

      it 'closes channel after block returns' do
        channel = Going::Channel.new do |ch|
          ch.push 1
        end
        channel.receive
        expect(channel).to be_closed
      end

      it 'does not close channel until block returns' do
        channel = Going::Channel.new do |ch|
          ch.push 1
          ch.push 2
        end
        channel.receive
        expect(channel).not_to be_closed
      end
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
        sleeper channel, :pushes, 1
        channel.close
      end
      expect { channel.push 1 }.to raise_error
    end

    it 'will wake a blocked shift' do
      Going.go do
        sleeper channel, :shifts, 1
        channel.close
      end
      expect { channel.receive }.to throw_symbol(:close)
    end

    it 'will reject all but the first #capacity pushes' do
      begin
        channel = Going::Channel.new 2
        Going.go do
          sleeper channel, :pushes, 3
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
        sleeper channel, :pushes, 1
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
        sleeper buffered_channel, :pushes, 1
        buffered_channel.push 2
      end
      Going.go do
        sleeper buffered_channel, :pushes, 2
        buffered_channel.push 3
      end

      sleeper buffered_channel, :pushes, 3
      1.upto(3).each do |i|
        expect(buffered_channel.receive).to eq(i)
      end
    end

    it 'returns the channel' do
      expect(buffered_channel.push(1)).to be(buffered_channel)
    end

    context 'when a shift is from a select_statement' do
      context 'when select_statement is already completed' do
        it 'attempts to complete with next shift' do
          i = nil
          Going.select do |s|
            channel.receive
            s.default
            th = Going.go do
              i = channel.receive
            end
            Going.go do
              sleeper channel, :shifts, 2
              channel.push 1
              th.join
            end.join
          end

          expect(i).to be(1)
        end
      end
    end
  end

  describe '#shift' do
    it 'is aliased as #receive' do
      expect(channel.method(:receive)).to eq(channel.method(:shift))
    end

    it 'is aliased as #next' do
      expect(channel.method(:next)).to eq(channel.method(:shift))
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
        sleeper channel, :shifts, 1
        sleep 0.25
        channel.push 1
      end
      now = Time.now
      channel.receive
      expect(elapsed_time(now)).to be > 0.2
    end

    context 'when closed' do
      it 'returns next message if any' do
        buffered_channel.push 1
        buffered_channel.close
        expect(buffered_channel.receive).to eq(1)
      end

      it 'throws :close if no messages' do
        channel.close
        expect { channel.receive }.to throw_symbol(:close)
      end
    end

    context 'when a push is from a select_statement' do
      context 'when select_statement is already completed' do
        it 'attempts to complete with next push' do
          i = nil

          Going.select do |s|
            channel.push 1
            s.default
            Going.go do
              channel.push 2
            end
            Going.go do
              sleeper channel, :pushes, 2
              i = channel.receive
            end.join
          end

          expect(i).to be(2)
        end
      end
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
      sleeper channel, :pushes, 1
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
        sleeper channel, :pushes, 1
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

  describe '#each' do
    it 'yields for each message until channel is closed' do
      Going.go do
        10.times do |i|
          channel.push i
        end
        channel.close
      end

      i = 0
      channel.each do |message|
        expect(message).to eq(i)
        i += 1
      end
      expect(i).to eq(10)
    end

    it 'returns an enumerator if no block is given' do
      expect(channel.each).to be_an Enumerator
    end
  end
end
