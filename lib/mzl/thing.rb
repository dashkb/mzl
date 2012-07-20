module Mzl
  class Thing
    attr_reader :subject, :defaults, :options

    def self.for(klass)
      @things_by_class ||= {}
      @things_by_class[klass] ||= new(klass)
    end

    def initialize(subject)
      raise ArgumentError unless subject.is_a?(Class)

      # the class we will be instantiating
      @subject = subject

      # this object will hold our DSL methods so we don't make a mess
      @dsl_proxy = DSLProxy.new

      # default parameters for things
      @defaults = Hash.new({})

      # our name in @subject
      @name = :mzl
    end

    # this is stupid and probably only here for that test I wrote earlier
    def dsl_methods
      @dsl_proxy.defs
    end

    def override_new(bool = true)
      if bool
        @subject.singleton_class.class_exec do
          alias_method(:mzl_orig_new, :new) if method_defined?(:new)
          def new(*args, &block)
            mzl.new(*args, &block)
          end
          @__mzl_new_overridden = true
        end
      elsif @subject.singleton_class.instance_variable_get(:@__mzl_new_overridden)
        @subject.singleton_class.class_exec do
          @__mzl_new_overridden = false
          remove_method(:new) # this is the shim new we defined above
        end
      end
    end

    def as(new_name)
      @subject.singleton_class.class_exec(@name, new_name) do |old_name, new_name|
        alias_method new_name, old_name
        undef_method(old_name)
      end
      @name = new_name
    end

    # define a DSL method
    def def(sym, opts = {}, &block)
      raise ArgumentError unless block_given?
      raise ArgumentError if @dsl_proxy.defs.include?(sym)
      @dsl_proxy.def(sym, @defaults[:def].merge(opts), &block)
    end

    def child(sym, klass, opts = {persist: true})
      child_method = Proc.new do |&block|
        # be a attr_reader for a new instance of the child class
        child = instance_variable_get(:"@#{sym}")
        child = instance_variable_set(:"@#{sym}", klass.mzl.new) unless child

        # mzl an optional block in the child
        child.mzl(&block) if block.is_a?(Proc)

        # and return it, of course
        child
      end

      if opts[:persist]
        @subject.send(:define_method, sym, &child_method)
      else
        self.def(sym, &child_method)
      end
    end

    def collection(sym, klass, opts = {})
      opts = {
        persist: true,
        plural: "#{sym}s"
      }.merge(opts)
    end

    def array(sym, klass, opts = {})
      collection(sym, klass, opts.merge(type: Array))
    end

    def hash(sym, klass, opts = {})
      collection(sym, klass, opts.merge(type: Hash))
    end

    # instance method not class method!
    def new(*args, &block)
      # we will need ourselves later
      _self = self

      # create an instance of subject
      instance = subject.respond_to?(:mzl_orig_new) ? subject.mzl_orig_new(*args) : subject.new(*args)
      instance = block_given? ? exec(instance, &block) : instance

      # Give the instance a mzl thing (_self)
      instance.singleton_class.send(:define_method, :mzl) do |&blk|
        _self.exec(self, &blk) if blk.is_a?(Proc)
        _self
      end

      # put the permanent methods on (in case they never call mzl with a block)
      @dsl_proxy.insert_mzl(instance, persist: true)

      # and return it
      instance
    end

    def exec(instance, &block)
      return instance unless block_given?

      # have the dsl proxy execute the block on behalf of that instance
      @dsl_proxy.exec_for(instance, &block)
    end
  end
end