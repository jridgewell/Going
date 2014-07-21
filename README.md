# Going [![Build Status](https://travis-ci.org/jridgewell/Going.svg)](https://travis-ci.org/jridgewell/Going)

Go for Ruby

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'going'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install going

## Usage

Brings Go's Channel and Goroutines to Ruby.

```ruby
require 'going'
# Require 'going/kernel' to get the unnamespaced `go` function
# require 'going/kernel'

class ConcurrentSieve
  def generator
    ch = Going::Channel.new
    Going.go do
      i = 1
      loop { ch.push(i += 1) }
    end
    ch
  end

  def filter(prime, from)
    ch = Going::Channel.new
    Going.go do
      loop do
        i = from.receive
        ch.push(i) if i % prime != 0
      end
    end
    ch
  end

  def initialize(n)
    ch = generator
    n.times do
      prime = ch.receive
      puts prime
      ch = filter(prime, ch)
    end
  end
end
```

## Contributing

1. Fork it ( https://github.com/jridgewell/going/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
