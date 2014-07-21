require 'going/kernel'

describe Kernel do
  it 'defines #go function' do
    expect(method(:go)).not_to be(nil)
  end

  it 'delegates to Going.go' do
    expect(Going).to receive(:go)
    go
  end

  it "returns Going.go's return value" do
    thread = double
    expect(Going).to receive(:go) { thread }
    expect(go).to be(thread)
  end
end
