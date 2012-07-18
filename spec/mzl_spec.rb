require 'spec_helper'
require 'examples/calculate'

describe 'Class' do
  let(:klass) do
    klass = Class.new
    klass.mzl.def :call_block do |*args, &block|
      block.call
    end

    klass.mzl.def :properties, persist: true do
      @properties ||= {}
    end

    klass.mzl.def :throw_the_instance do
      throw :the_instance, self
    end

    klass
  end

  describe '.mzl' do
    it 'responds with a Mzl::Thing' do
      Class.mzl.should be_a(Mzl::Thing)
    end

    specify 'subject is the calling class' do
      Class.mzl.subject.should == Class
      klass.mzl.subject.should == klass
      klass.mzl.new.mzl.subject.should == klass
    end

    specify 'with a block is the same as .mzl.new' do
      instance = klass.mzl do
        properties[:foo] = :bar
      end

      instance.instance_variable_get(:@properties)[:foo].should == :bar
    end

    describe '.def' do
      it 'defines a DSL method for the subject' do
        klass.mzl.dsl_methods.should == [:call_block, :properties, :throw_the_instance]
      end

      it 'can define methods which take blocks' do
        catch(:block) do
          klass.mzl.new do
            call_block do
              throw :block, self
            end
          end
        end.should be_a(klass)
      end

      it 'executes the methods in the correct context' do
        catch(:the_instance) do
          klass.mzl.new do
            throw_the_instance
          end
        end.should be_a(klass)
      end

      it 'takes option :persist => true to permanently define the method on the instance' do
        klass.mzl do
          properties[:foo] = 'whatever'
        end.properties[:foo].should == 'whatever'
      end

      it 'by default defines methods only available during mzl' do
        expect {
          klass.mzl.new
        }
      end
    end

    describe '.new' do
      it 'returns an instance of of the subject class' do
        klass.mzl.new.should be_a(klass)
      end

      it 'passes parameters to the original .new method' do
        String.mzl.new("hello").should == "hello"
      end

      it 'sets self to the instance' do
        catch(:instance) do
          klass.mzl.new do
            throw :instance, self
          end.should be_a(klass)
        end
      end

      it 'instance_execs a block against the instance with mzl methods available' do
        instance_a = klass.mzl.new do
          properties[:foo] = :bar
        end

        instance_b = klass.mzl.new do
          properties[:foo] = :baz
        end

        [[instance_a, :bar], [instance_b, :baz]].each do |pair|
          instance, val = pair
          props = instance.instance_variable_get(:@properties)
          props.should be_a(Hash)
          props[:foo].should == val
        end
      end

      it 'can override klass.new' do
        klass.mzl.new.should respond_to(:properties)
        klass.new.should_not respond_to(:properties)

        klass.mzl.override_new
        klass.new.should respond_to(:properties)
        klass.mzl.override_new(false)
        klass.new.should_not respond_to(:properties)
      end
    end

    describe '.as' do
      it 'renames mzl to something else' do
        klass.class_exec do
          mzl_thing = mzl
          mzl.as :zl
        end

        klass.should_not respond_to(:mzl)
        klass.should respond_to(:zl)

        klass.class_exec do
          zl.as :mzl
        end

        klass.should_not respond_to(:zl)
        klass.should respond_to(:mzl)
      end
    end
  end
end

describe 'Mzl instances' do
  let(:klass) { Examples::Calculate }

  it 'should not respond to DSL methods' do
    klass.mzl.new.should_not respond_to(:add)
  end

  it 'should respond to normal instance methods' do
    klass.mzl.new.total.should == 0

    catch(:total) do
      klass.mzl.new do
        throw(:total, total)
      end
    end.should == 0
  end

  it 'should put two and two together' do
    klass.mzl.new do
      add 2, 2
    end.total.should == 4
  end

  it 'should have a mzl thing' do
    instance = klass.mzl.new
    instance.should respond_to(:mzl)
    instance.mzl.should be_a(Mzl::Thing)
  end

  it 'can use the mzl thing to call dsl methods later' do
    instance = klass.mzl.new
    expect {
      instance.mzl do
        add 1, 1, 1, 1
      end
    }.to change { instance.total }.by(4)
  end
end