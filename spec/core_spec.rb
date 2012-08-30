require 'spec_helper'

describe 'Class.mzl' do
  let(:superclass) { Class.new { mzl.override_new } }
  let(:klass) { Class.new(superclass) }
  let(:child_klass) {
    Class.new(klass) do
      mzl.def(:i_am) { |val| @identity = val }
      mzl.def(:who_am_i?, persist: true) { @identity }
      def initialize(opts = {}) @opts = opts; end
      attr_reader :opts
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

  describe '.attr' do
    it 'defines DSL setter and permanent getter' do
      klass.mzl.attr(:foo)

      instance = klass.new do
        foo :bar
      end

      instance.foo.should == :bar

      expect {
        instance.foo :bar
      }.to raise_exception(ArgumentError)
    end

    it 'slips passed options into the value' do
      klass.mzl.attr(:foo)

      instance = klass.new do
        foo :bar, :awesome, :right?, i: 'agree'
      end

      instance.foo.should == :bar
      instance.__mzl_attr_opts[:foo][:awesome].should be_true
      instance.__mzl_attr_opts[:foo][:right?].should be_true
      instance.__mzl_attr_opts[:foo][:i].should == 'agree'
    end

    it 'can be aliased' do
      klass.mzl.attr(:foo)
      klass.mzl.alias(:bar, :foo, :aliased?)

      instance = klass.new do
        bar :foo
      end

      instance.foo.should == :foo
      instance.__mzl_attr_opts[:foo][:aliased?].should be_true

      expect { instance.bar }.to raise_exception(NoMethodError)
    end

    it 'accepts a block that can be instance execd to return the default value' do
      klass.mzl.attr(:foo) { :bar }

      instance = klass.new do
        foo.should == :bar
      end
    end
  end

  describe '.alias' do
    it 'creates another name for a method' do
      child_klass.mzl.alias(:me_am, :i_am)
      bizarro = child_klass.new { me_am 'superman' }
      bizarro.who_am_i?.should == 'superman'
    end

    describe 'with options provided' do
      before(:each) do
        klass.mzl.array :thing, child_klass
        klass.mzl.alias :big_thing, :thing, :big

        klass.mzl.hash :named_thing, child_klass
        klass.mzl.alias :big_named_thing, :named_thing, :big
      end

      it 'discards options for methods that are not expecting any' do
        child_klass.mzl.alias :me_am, :i_am, :awesome
        not_awesome = child_klass.new { me_am 'superman', :awesome }

        not_awesome.who_am_i?.should == 'superman'
        not_awesome.opts[:awesome].should_not be_true
      end

      it 'calls the aliased method with the options' do
        thing_jar = klass.new do
          thing { i_am :thing_one }
          big_thing { i_am :thing_two }
        end

        thing_jar.things.first.who_am_i?.should == :thing_one
        thing_jar.things.last.who_am_i?.should == :thing_two

        thing_jar.things.last.opts[:big].should be_true
        thing_jar.things.first.opts[:big].should be_nil
      end

      it 'will not clobber passed options' do
        thing_jar = klass.new do
          big_thing { i_am :thing_one }
          big_thing(big: false) { i_am :thing_two }
        end

        thing_jar.things.first.opts[:big].should be_true
        thing_jar.things.last.opts[:big].should be_false
      end

      it 'works with hashes' do
        thing_jar = klass.new do
          named_thing(:one) { i_am :thing_one }
          big_named_thing(:two) { i_am :thing_two }
        end

        thing_jar.named_things.keys.should == [:one, :two]
        thing_jar.named_things[:one].opts[:big].should be_false
        thing_jar.named_things[:two].opts[:big].should be_true
      end

      it 'works through a delegate' do
        delegator = Class.new(superclass) do
          def initialize(delegate)
            @delegate = delegate_clas
          end

          mzl.delegate { @delegate }
        end

        expect {
          thing_jar = delegator.new(klass.new) do
            big_named_thing(:two) { i_am :thing_two }
          end
        }.to_not raise_exception(NoMethodError)
      end
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

    it 'passes named parameters to child.new' do
      instance.the_child(foo: 'bar').opts.should == {foo: 'bar'}
    end

    it 'only passes named parameters to child.new' do
      expect {
        instance.the_child('omg', foo: 'bar')
      }.to raise_exception
    end

    it 'optifies symbols like rspec' do
      instance.the_child(:yes!, awesome?: true).opts.should == {
        awesome?: true,
        yes!: true
      }
    end
  end
end
