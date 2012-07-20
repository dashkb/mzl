require 'spec_helper'

describe 'Class.mzl' do
  let(:klass) { Class.new { mzl.override_new } }
  let(:child_klass) { klass }

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
        properties[:foo] = 'whatever'
      end

      r.properties[:foo].should == 'whatever'
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

  describe '.array', :focus do
    let(:parent_klass) {
      klass.mzl.array(:thing, child_klass)
      klass
    }

    it 'defines a method to add a child to an array' do
      instance = parent_klass.new do
        2.times { thing }
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
  end

  describe '.hash', :focus do
    let(:parent_klass) {
      klass.mzl.hash(:thing, child_klass)
      klass
    }

    it 'defines a method to add a child to a hash with a key' do
      instance = parent_klass.new do
        thing :one
        thing :two
      end

      instance.things.should be_a(Hash)
      instance.things.size.should == 2
      instance.things.keys.should == [:one, :two]
    end
  end
end