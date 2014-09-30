# Going [![Build Status](https://travis-ci.org/jridgewell/Going.svg)](https://travis-ci.org/jridgewell/Going)

A Ruby implementation of Go Channels.

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

Wording stolen from the [Go Language
Specification](https://golang.org/ref/spec) and [Effective Go
Document](https://golang.org/doc/effective_go.html), and converted over
into the equivalent Ruby code.

### Channels

Unbuffered channels combine communication — the exchange of a value —
with synchronization — guaranteeing that two calculations ("goroutines",
or threads) are in a known state.

There are lots of nice idioms using channels. Here's one to get us
started. A channel can allow the launching goroutine to wait for the
sort to complete.

```ruby
list = [3, 2, 1]
c = Going::Channel.new  # Allocate a channel.

# Start the sort in a goroutine; when it completes, signal on the channel.
Going.go do
    list.sort!
    c.push 1  # Send a signal; value does not matter.
end

# doSomethingForAWhile
c.receive   # Wait for sort to finish; discard sent value.
```

Receivers always block until there is data to receive. If the channel is
unbuffered, the sender blocks until the receiver has received the value.
If the channel has a buffer, the sender blocks only until the value has
been copied to the buffer; if the buffer is full, this means waiting
until some receiver has retrieved a value.

A buffered channel can be used like a semaphore, for instance to limit
throughput. In this example, incoming requests are passed to `handle`,
which sends a value into the channel, processes the request, and then
receives a value from the channel to ready the "semaphore" for the next
consumer. The capacity of the channel buffer limits the number of
simultaneous calls to process.

```ruby
sem = Going::Channel.new(MaxOutstanding)

def handle(request)
    sem.push 1    # Wait for active queue to drain.
    process r     # May take a long time.
    sem.receive   # Done; enable next request to run.
end

def serve(request_queue)
    request_queue.each do |req|
        Going.go do
            handle req  # Don't wait for handle to finish.
        end
    end
end
```

Once `MaxOutstanding` handlers are executing `process`, any more will
block trying to send into the filled channel buffer, until one of the
existing handlers finishes and receives from the buffer.

This design has a problem, though: `serve` creates a new goroutine for
every incoming request, even though only `MaxOutstanding` of them can
run at any moment. As a result, the program can consume unlimited
resources if the requests come in too fast. We can address that
deficiency by changing `serve` to gate the creation of the goroutines.
Here's an obvious solution.

```ruby
def serve(request_queue) {
    request_queue.each do |req|
        sem.push 1
        Going.go do
            process req
            sem.receive
        end
    end
end
```

Going back to the general problem of writing the server, another
approach that manages resources well is to start a fixed number of
`handle` goroutines all reading from the request channel. The number of
goroutines limits the number of simultaneous calls to process. This
`serve` function also accepts a channel on which it will be told to
exit; after launching the goroutines it blocks receiving from that
channel.

```ruby
def handle(request_queue)
    request_queue.each do |req|
        process req
    end
end

def serve(request_queue, quit) {
    # Start handlers
    MaxOutstanding.times do
        Going.go do
            handle request_queue
        end
    end
    quit.receive  # Wait to be told to exit.
end
```

### Close

For a channel `ch`, the method `ch.close` records that no more values
will be sent on the channel. Sending to a closed channel causes an
exception to be thrown. After calling `#close`, and after any previously
sent values have been received, receive operations will raise
`StopIteration`.

```ruby
ch = Going::Channel.new 2

# Push an initial value into the buffered channel
ch.push 1

# Close the channel, preventing any futher message
ch.close

begin
    ch.push 2
rescue
    # Sending to a closed channel causes an exception
end

# You may receive already sent values
ch.receive # => 1

begin
    ch.receive
rescue StopIteration
    # Closed channels raise StopIteration when there are no more messages
end
```

### Size

For a channel `ch`, the method `ch.size` returns the number of completed
send operations on the channel. For an unbuffered channel, that number
is always 0.

```ruby
unbuffered_channel = Going::Channel.new
unbuffered_channel.size # => 0

Going.go do
    unbuffered_channel.push 'message'
end
# after the goroutine has blocked on send
unbuffered_channel.size # => 0


buffered_channel = Going::Channel.new 2
buffered_channel.size # => 0

buffered_channel.push 'message'
buffered_channel.size # => 1

buffered_channel.push 'message'
buffered_channel.size # => 2

buffered_channel.receive
buffered_channel.size # => 1
```

### Capacity

For a channel `ch`, the method `ch.capacity` returns the buffer size of
the channel. For an unbuffered channel, that number is 0.

```ruby
unbuffered_channel = Going::Channel.new
unbuffered_channel.capacity # => 0


buffered_channel = Going::Channel.new 2
buffered_channel.capacity # => 2

buffered_channel.push 'message'
buffered_channel.capacity # => 2
```

### Select Statements

A "select" statement chooses which of a set of possible send or receive
operations will proceed. It acts similar to a "case" statement but
with the cases all referring to communication operations.

Execution of a "select" statement proceeds in several steps:

1. For all the cases in the statement, the channel operands of receive
   operations and the channel and right-hand-side expressions of send
   statements are evaluated exactly once, in source order, upon entering
   the "select" statement. The result is a set of channels to receive
   from or send to, and the corresponding values to send. Any side
   effects in that evaluation will occur irrespective of which (if any)
   communication operation is selected to proceed. Expressions on the
   left-hand side of a receive statement with a variable assignment are
   not evaluated.

2. If one or more of the communications can proceed, a single one that
   can proceed is chosen in source order.  Otherwise, if there is a
   default case, that case is chosen. If there is no default case, the
   "select" statement blocks until at least one of the communications
   can proceed.

3. Unless the selected case is the default case, the respective
   communication operation is executed.

4. If the selected case is a receive statement with a variable
   assignment, the corresponding block is executed with the received
   message as the first parameter. A second, optional, hash is
   also passed, with a single key `ok`. `ok` will equal `true` if the
   channel is not closed, or `false` if the channel is closed.

5. If the selected case is a send statement, the corresponding block is
   executed.

```ruby
Going.select do
  channel.receive { |msg|
    # do something with `msg`.
  }

  channel2.push(1) {
    # do something after pushing
  }

  channel3.receive { |msg, ok: true|
    if ok
      # do something with msg
    else
      # channel3 was closed, msg is `nil`
    end
  }

  timeout(5) {
    # 5 second passed and no channel operations succeeded.
  }

  default {
    # An immediately executing block, if nothing has succeeded yet
  }
end
```


## Obligatory Sieve of Eratosthenes Example

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
