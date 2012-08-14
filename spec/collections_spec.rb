require 'spec_helper'

describe 'Class.mzl' do
  let(:klass) { Class.new { mzl.override_new } }
  let(:child_klass) {
    Class.new(klass) do
      mzl.def(:i_am) { |val| @identity = val }
      mzl.def(:who_am_i?, persist: true) { @identity }
      def initialize(opts = {}) @opts = opts; end
      attr_reader :opts
    end
  }
  
  describe '.array' do
    let(:parent_klass) {
      klass.mzl.array(:thing, child_klass)
      klass
    }

    it 'defines a method to add a child to an array' do
      instance = parent_klass.new do
        thing
      end

      instance.should respond_to(:things)
      instance.should_not respond_to(:thing)
      instance.things.should be_a(Array)
      instance.things.size.should == 1

      expect { instance.mzl {
        4.times { thing }
      }}.to change { instance.things.size }.by(4)
    end

    it 'stores childs in an array' do
      parent_klass.new do
        5.times { thing }
      end
    end

    it 'stores values' do
      parent_klass.new do
        5.times { |i| thing { i_am i } }
      end.things.collect(&:who_am_i?).should == [0, 1, 2, 3, 4]
    end

    it 'can be empty' do
      parent_klass.new.things.should == []
    end

    it 'can be nested' do
      inner = Class.new(child_klass)
      middle = Class.new(child_klass) { mzl.array(:thing, inner) }
      outer = Class.new(klass) { mzl.array(:thing, middle) }

      instance = outer.new do
        thing do
          thing { i_am :one_one }
          thing { i_am :one_two }
        end

        thing do
          thing { i_am :two_one }
          thing { i_am :two_two }
        end
      end

      instance.things.first.things.last.who_am_i?.should == :one_two
      instance.things.last.things.first.who_am_i?.should == :two_one
    end

    it 'can be mzl-only' do
      klass.mzl.array(:thing, child_klass, persist: false)
      instance = klass.new do
        thing { i_am :me }

        things[0].who_am_i?.should == :me
      end

      instance.should_not respond_to(:things)
      instance.instance_variable_get(:@things)[0].who_am_i?.should == :me
    end
  end

  describe '.hash' do
    let(:parent_klass) {
      klass.mzl.hash(:thing, child_klass)
      klass
    }

    it 'defines a method to add a child to a hash with a key' do
      instance = parent_klass.new do
        thing(:one) { i_am :first_thing }
        thing(:two) { i_am :second_thing }
      end

      instance.things.should be_a(Hash)
      instance.things.size.should == 2
      instance.things.keys.should == [:one, :two]
      instance.things[:one].who_am_i?.should == :first_thing
      instance.things[:two].who_am_i?.should == :second_thing
    end

    it 'allows arbitrary keys and values' do
      instance = parent_klass.new do
        thing(:one) { i_am :thing_one }
        thing('one') { i_am 'thing_one' }
      end

      instance.things.size.should == 2
      instance.things.keys.should == [:one, 'one']
      instance.things[:one].who_am_i?.should == :thing_one
      instance.things['one'].who_am_i?.should == 'thing_one'
    end

    it 'can be nested' do
      inner = Class.new(child_klass)
      middle = Class.new(child_klass) { mzl.hash(:thing, inner) }
      outer = Class.new(klass) { mzl.hash(:thing, middle) }

      instance = outer.new do
        thing :one do
          thing(:one_one) { i_am :one_one }
          thing(:one_two) { i_am :one_two }
        end

        thing :two do
          thing(:two_one) { i_am :two_one }
          thing(:two_two) { i_am :two_two }
        end
      end

      instance.things[:one].things[:one_one].who_am_i?.should == :one_one
      instance.things[:two].things[:two_two].who_am_i?.should == :two_two
    end

    it 'passes options to instantiated item in hash' do
      thing_class = Class.new(klass) do
        attr_reader :args
        def initialize(args)
          @args = args
        end
      end

      parent = Class.new(klass) do
        mzl.hash(:thing, thing_class)
      end

      instance = parent.new do
        thing :one, :this => 'that'
        thing :two, :these => 'those'
      end

      instance.things[:one].args.should == {this: 'that'}
      instance.things[:two].args.should == {these: 'those'}
    end
  end

  describe 'collection opacity' do
    let(:parent_klass) { Class.new(klass) {
      mzl.def(:foo) { |val| @foo = val }
    }}

    it 'works as expected' do
      opaque_parent, transparent_parent = 2.times.collect { Class.new(parent_klass) }
      opaque_parent.mzl.array(:thing, child_klass, :opaque)
      transparent_parent.mzl.array(:thing, child_klass)

      expect {
        opaque_parent.new do
          thing do
            foo :bar
          end
        end
      }.to raise_exception

      instance = transparent_parent.new do
        thing do
          foo :bar
        end
      end

      instance.instance_variable_get(:@foo).should == :bar
    end
  end
end
