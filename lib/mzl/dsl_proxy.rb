 module Mzl
  class DSLProxy
    attr_accessor :delegate_proc

    def initialize
      @defs = {}
    end

    # for inheritance
    def clone
      # clone ourselves
      the_clone = super

      # whoa who is the clone? us or them? (who cares?)
      @defs = @defs.clone

      # return the clone
      the_clone
    end

    # define a method that will be available on objects created with
    # the mzl object that created this object
    def def(m, opts = nil, &block)
      if block_given?
        @defs[m] = [block, opts]
      else
        @defs[m]
      end
    end

    # a list of our methods
    def defs
      @defs.keys
    end

    # leave this def on the instance? (so it is accessible without mzl)
    def persist?(m)
      @defs[m][1][:persist]
    end

    # take over method_missing
    def insert_mm(instance)
      _delegate_proc = delegate_proc

      instance.singleton_class.send(:alias_method, :mzl_orig_mm, :method_missing)
      instance.singleton_class.send(:define_method, :method_missing) do |m, *args, &block|
        if Mzl::Thing.nesting_of(self).any? { |object| object.respond_to?(m) }
          @__mzl_parent.send(m, *args, &block)
        else
          begin
            mzl_orig_mm(m, *args, &block)
          rescue NameError
            raise unless _delegate_proc.is_a?(Proc) && delegate = instance.instance_exec(&_delegate_proc)
            delegate.send(m, *args, &block)
          end
        end
      end

      instance.singleton_class.send(:alias_method, :mzl_orig_respond_to?, :respond_to?)
      instance.singleton_class.send(:define_method, :respond_to?) do |m|
        self.class.mzl.dsl_proxy.defs.include?(m) || mzl_orig_respond_to?(m)
      end
    end

    # release method_missing
    def extract_mm(instance)
      instance.singleton_class.send(:remove_method, :method_missing)
      instance.singleton_class.send(:alias_method, :method_missing, :mzl_orig_mm)

      instance.singleton_class.send(:remove_method, :respond_to?)
      instance.singleton_class.send(:alias_method, :respond_to?, :mzl_orig_respond_to?)
    end

    # define our DSL methods on the instance's metaclass
    def insert_dsl(instance, filter = {})
      @defs.each do |m, ary|
        blk, opts = ary
        next unless filter.empty? || opts == filter
        instance.singleton_class.send(:define_method, m, &blk)
      end
    end

    # remove all our methods
    def extract_dsl(instance)
      defs.each do |m|
        instance.singleton_class.send(:remove_method, m) unless persist?(m)
      end
    end

    # execute the block against the instance with our methods
    # available.  afterwards, remove the :persist => false ones
    def exec_for(instance, &block)
      # setup
      insert_dsl(instance)
      insert_mm(instance) unless instance.instance_variable_get(:@__mzl_opaque_scope)

      # exec
      instance.instance_exec(&block)

      # teardown
      extract_dsl(instance)
      extract_mm(instance) unless instance.instance_variable_get(:@__mzl_opaque_scope)

      # return the instance
      instance
    end
  end
end
