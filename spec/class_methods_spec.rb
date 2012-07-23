require 'spec_helper'

describe 'Class.mzl' do
  let(:klass) { Class.new { mzl.override_new } }
  let(:child_klass) {
    Class.new(klass) do
      mzl.def(:i_am) { |val| @identity = val }
      mzl.def(:who_am_i?, persist: true) { @identity }
    end
  }

  describe '.def' do
    it 'defines a DSL method for the subject' do
      klass.mzl.dsl_methods.should == []
      klass.mzl.def(:foo) { :bar }
      klass.mzl.dsl_methods.should == [:foo]
    end

    it 'can define methods which take blocks' do
      klass.mzl.def(:call_block) { |&block| yield if block_given? }

      catch(:block) do
        klass.new do
          call_block do
            throw :block, self
          end
        end
      end.should be_a(klass)
    end

    it 'executes the methods in the correct context' do
      klass.mzl.def(:throw_the_instance) { throw(:the_instance, self) }

      catch(:the_instance) do
        klass.new do
          throw_the_instance
        end
      end.should be_a(klass)
    end

    it 'takes option :persist => true to permanently define the method on the instance' do
      klass.mzl.def :properties, persist: true do 
        @properties ||= {}
      end

      r = klass.new do
        properties[:foo] = :bar
      end

      r.properties[:foo].should == :bar
    end

    it 'by default defines methods only available during mzl' do
      ping = Object.new
      ping_pong = lambda { ping.pong }
      klass.mzl.def(:foo, &ping_pong) 

      expect {
        klass.class_exec { foo }
      }.to raise_exception

      expect {
        Class.new.new.instance_exec { foo }
      }.to raise_exception

      ping.should_receive(:pong).exactly(2).times

      klass.new { foo }
      klass.mzl { foo }
      Class.new.new { foo } # no mzl.override_new
    end

    it ':persist => true can be set to be default, and overridden' do
      klass.mzl.defaults[:def][:persist] = true
      klass.mzl.def :properties do
        @properties ||= {}
      end

      klass.mzl.def :mzl_only, persist: false do
        @mzl_only = :sweet
      end

      instance = klass.new do
        properties[:foo] = :bar
        mzl_only
      end

      instance.properties[:foo].should == :bar
      instance.instance_variable_get(:@mzl_only).should == :sweet
      instance.should_not respond_to(:mzl_only)
    end
  end

  describe '.defaults' do
    it 'returns a hash of hashes' do
      klass.mzl.defaults.should == {}
      klass.mzl.defaults[:foo].should == {}
    end

    it 'persists changes' do
      klass.mzl.defaults[:foo] = :bar
      klass.mzl.defaults[:foo].should == :bar
      klass.mzl.defaults.should == {foo: :bar}

      klass.mzl.defaults[:bar][:foo] = :bam
      klass.mzl.defaults[:bar].should == {foo: :bam}
    end
  end

  describe '.child' do
    let(:parent_klass) {
      klass.mzl.child(:the_child, child_klass)
      klass
    }
    let(:instance) { parent_klass.new }

    it 'is like attr_accessor' do
      instance.should respond_to(:the_child)
      instance.the_child.should be_a(child_klass)
    end

    it 'mzls a block' do
      the_instance = catch(:the_instance) do
        instance.the_child do
          throw(:the_instance, self)
        end
      end

      the_instance.should be_a(child_klass)
    end

    it 'is memoized' do
      instance.the_child.should == instance.the_child
    end
  end

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

    it 'will run the same block on multiple keys' do
      instance = parent_klass.new do
        thing(:one, :two) { i_am :one_or_two }
        thing(:three, :four) { i_am :three_or_four }
      end

      instance.things.should be_a(Hash)
      instance.things.size.should == 4
      instance.things[:one].who_am_i?.should == :one_or_two
      instance.things[:four].who_am_i?.should == :three_or_four
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
  end
end