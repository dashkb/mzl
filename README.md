# Mzl

Difficult to understand versions of your favorite concepts.

## What does it do?

Mzl provides a `mzl` method on classes that can be used to create DSLs and probably other things too.  Since I find myself talking in circles when I try to explain it, let's look at some code.

```ruby
require 'mzl'

class Dog
  mzl.override_new

  mzl.def :voice do |voice|
      @voice = voice
  end
    
  mzl.def :speak, persist: true do
      @voice
  end
end

spot = Dog.new do
  voice 'bark'
  speak # => 'bark'
end

spot.speak # => 'bark'
spot.voice 'ruff' # => NoMethodError: undefined method `voice' for #<Dog:0x007fe46b8bbd50 @voice="bark">

# and if you really want to change the voice, of course you can cheat
spot.mzl { voice 'ruff'}
spot.speak # => 'ruff'
```


## Installation

Add this line to your application's Gemfile:

    gem 'mzl'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install mzl


## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
