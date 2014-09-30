require 'going'

describe Going::SelectStatement do
  let(:channel) { Going::Channel.new }
  let(:buffered_channel) { Going::Channel.new 1 }
  let(:spy) { Spy.new }
  let(:dont_call) { Spy.new }

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

  describe 'Going.select' do
    it 'blocks until a channel operation succeeds' do
      now = Time.now
      Going.select do |s|
        channel.receive

        Going.go do
          sleep 0.25
          channel.push 1
        end
      end
      expect(elapsed_time(now)).to be > 0.2
    end

    it 'does not block if a channel operation immediately succeeds' do
      now = Time.now
      Going.select do |s|
        buffered_channel.push 1
      end
      expect(elapsed_time(now)).to be < 0.2
    end

    it 'calls block on operation that succeeds' do
      third_channel = Going::Channel.new 1
      Going.select do |s|
        channel.receive(&dont_call)
        buffered_channel.push(1, &spy)
        third_channel.push(2, &dont_call)
      end
      expect(spy).to be_called
      expect(dont_call).not_to be_called
    end

    it 'does not call other blocks' do
      Going.select do |s|
        channel.push(1, &dont_call)
        buffered_channel.push 2
        Going.go do
          channel.receive
        end
      end
      sleeper channel, :shifts, 1
      expect(dont_call).not_to be_called
    end

    it 'can not succeed from own operations' do
      now = Time.now
      Going.select do |s|
        channel.push(1, &dont_call)
        channel.receive(&spy)
        channel.push(2, &dont_call)
        Going.go do
          sleep 0.25
          channel.push(3)
        end
      end
      expect(elapsed_time(now)).to be > 0.2
      expect(spy.args.first).to eq(3)
      expect(dont_call).not_to be_called
    end

    it 'does not complete other operations if already succeeded' do
      Going.select do |s|
        buffered_channel.receive(&dont_call)
        s.default
        Going.go do
          buffered_channel.push 1
        end.join
      end
      expect(dont_call).not_to be_called
    end

    it 'does not preserve channel operations that are not selected' do
      buffered_channel = Going::Channel.new 2
      Going.select do |s|
        buffered_channel.push 1
        buffered_channel.push 2
      end
      expect(buffered_channel.size).to eq(1)
    end

    context 'when an error is raised' do
      let(:buffered_channel) { Going::Channel.new 2 }

      it 'does not preserve channel operations when raised in on_complete block' do
        begin
          Going.select do |s|
            buffered_channel.push(1) { fail }
            buffered_channel.push 2
          end
        rescue
          expect(buffered_channel.size).to eq(1)
        end
      end

      it 'does not preserve channel operations when raised inline' do
        begin
          Going.select do |s|
            buffered_channel.push 1
            buffered_channel.push 2
            fail
          end
        rescue
          # TODO: Should be zero
          # Need to implement deferred completion
          expect(buffered_channel.size).to eq(1)
        end
      end
    end

    it 'calls succeeding block after the select_statement has been evaluated' do
      Going.select do |s|
        s.default do
          expect(Going::SelectStatement.instance).to be_nil
        end
      end
    end

    context 'buffered channels' do
      it 'will preserve an incomplete push' do
        Going.select do |s|
          buffered_channel.push(1, &spy)
        end
        expect(buffered_channel.size).to eq(1)
      end

      it 'succeeds when blocked push is now under capacity' do
        buffered_channel.push 1
        Going.select do |s|
          buffered_channel.push(2, &spy)
          Going.go do
            buffered_channel.receive
          end
        end
        expect(spy).to be_called
      end
    end
  end

  describe 'succeeding push' do
    it 'passes nothing to the block' do
      Going.select do |s|
        buffered_channel.push(1, &spy)
      end

      expect(spy.args).to eq([])
    end
  end

  describe 'succeeding receive' do
    it 'passes message as arg to the block' do
      buffered_channel.push 1
      Going.select do |s|
        buffered_channel.receive(&spy)
      end

      expect(spy.args.first).to eq(1)
    end

    it "passes true as `ok` param to the block" do
      buffered_channel.push 1
      Going.select do |s|
        buffered_channel.receive(&spy)
      end

      expect(spy.args.last).to eq({ ok: true })
    end
  end

  describe 'closed channel' do
    before(:each) { channel.close }

    describe 'push' do
      context 'when select fails' do
        it 'raises error' do
          expect do
            Going.select do |s|
              channel.push 1
            end
          end.to raise_error
        end

        it 'does not call block' do
          begin
            Going.select do |s|
              channel.push(1, &dont_call)
            end
          rescue
            expect(dont_call).not_to be_called
          end
        end
      end

      context 'when select succeeds' do
        it 'does not raise error' do
          expect do
            Going.select do |s|
              channel.push 1
              s.default
            end
          end.not_to raise_error
        end

        it 'does not call block' do
          Going.select do |s|
            channel.push(1, &dont_call)
            s.default
          end
          expect(dont_call).not_to be_called
        end
      end
    end

    describe 'receive' do
      it 'can receive buffered messages' do
        buffered_channel.push 1
        buffered_channel.close

        Going.select do |s|
          buffered_channel.receive(&spy)
        end
        expect(spy.args.first).to eq(1)
      end

      it 'is considered a success' do
        Going.select do |s|
          channel.receive(&spy)
        end
        expect(spy).to be_called
      end

      it 'passes nil as arg to the block' do
        Going.select do |s|
          channel.receive(&spy)
        end
        expect(spy.args.first).to be_nil
      end

      it "passes false as `ok` param to the block" do
        Going.select do |s|
          channel.receive(&spy)
        end
        expect(spy.args.last).to eq({ ok: false })
      end
    end
  end

  describe 'closing channel' do
    describe 'push' do
      context 'when select fails' do
        it 'blocked push raises error' do
          expect do
            Going.select do |s|
              channel.push 1
              channel.close
            end
          end.to raise_error
        end

        it 'does not call block' do
          begin
            Going.select do |s|
              channel.push(1, &dont_call)
              channel.close
            end
          rescue
            expect(dont_call).not_to be_called
          end
        end
      end

      context 'when select succeeds' do
        it 'does not raise error if select succeeds' do
          Going.select do |s|
            channel.push 1
            channel.receive
            channel.close
          end
        end

        it 'does not call block' do
          Going.select do |s|
            channel.push(1, &dont_call)
            channel.receive
            channel.close
          end
          expect(dont_call).not_to be_called
        end
      end
    end

    describe 'receive' do
      it 'is considered a success' do
        Going.select do |s|
          channel.receive(&spy)
          channel.close
        end
        expect(spy).to be_called
      end

      it 'passes nil as arg to the block' do
        Going.select do |s|
          channel.receive(&spy)
          channel.close
        end
        expect(spy.args.first).to be_nil
      end

      it "passes false as `ok` param to the block" do
        Going.select do |s|
          channel.receive(&spy)
          channel.close
        end
        expect(spy.args.last).to eq({ ok: false })
      end
    end
  end


  describe '#default' do
    it 'never blocks' do
      now = Time.now
      Going.select do |s|
        s.default
      end
      expect(elapsed_time(now)).to be < 0.2
    end

    it 'is not called if select statement is already succeeded' do
      Going.select do |s|
        buffered_channel.push 1
        s.default(&dont_call)
      end
      expect(dont_call).not_to be_called
    end

    it 'is not called if select statement succeeds' do
      Going.select do |s|
        s.default(&dont_call)
        buffered_channel.push 1
      end
      expect(dont_call).not_to be_called
    end

    it 'will be prioritized over a push on a closed channel' do
      channel.close
      Going.select do |s|
        s.default(&spy)
        channel.push 1
      end
      expect(spy).to be_called
    end

    it 'is prioritized over a push on a closed channel' do
      channel.close
      Going.select do |s|
        channel.push 1
        s.default(&spy)
      end
      expect(spy).to be_called
    end

    it 'calls its block on success' do
      Going.select do |s|
        s.default(&spy)
      end
      expect(spy).to be_called
    end

    it 'passes nothing to the block' do
      Going.select do |s|
        s.default(&spy)
      end
      expect(spy.args).to eq([])
    end
  end

  describe '#timeout' do
    it 'completes the select statement after given time' do
      now = Time.now
      Going.select do |s|
        s.timeout(0.25)
      end
      expect(elapsed_time(now)).to be > 0.2
    end

    it 'is not called if select statement is already completed' do
      ch = nil
      Going.select do |s|
        ch = s.timeout(0.1, &dont_call)
        s.default
      end
      sleeper ch, :pushes, 0
      expect(dont_call).not_to be_called
    end

    it 'calls its block on success' do
      Going.select do |s|
        s.timeout(0, &spy)
      end
      expect(spy).to be_called
    end

    it 'passes nothing to the block' do
      Going.select do |s|
        s.timeout(0, &spy)
      end
      expect(spy.args).to eq([])
    end
  end
end
