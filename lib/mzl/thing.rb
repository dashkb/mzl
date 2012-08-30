require 'json'

module Mzl
  class Thing
    attr_reader :subject, :defaults, :dsl_proxy

    # find or create
    def self.for(klass)
      @things_by_class ||= {}
      @things_by_class[klass] ||= new(klass)
    end

    # find or nil
    def self.for?(klass)
      @things_by_class ||= {}
      @things_by_class.has_key?(klass) ? @things_by_class[klass] : nil
    end

    # easy access to an object's mzl parent
    def self.parent_of(object)
      object.instance_variable_get(:@__mzl_parent)
    end

    # array of mzl nesting like [parent, inner, .., innermost]
    def self.nesting_of(object)
      parent = parent_of(object)
      parent ? [*nesting_of(parent), object] : [object]
    end

    # expects a bunch of symbols to be set to `true` in the resulting
    # hash.  if the last argument is a hash, we build onto that hash
    def self.optify(*args)
      opts = args.last.is_a?(Hash) ? args.pop : {}

      while args.last.is_a?(Symbol)
        sym = args.pop
        opts[sym] = true unless opts.has_key?(sym)
      end

      raise ArgumentError unless args.empty?
      opts
    end

    # Like optify, but return an array like [arg, arg, {optified}]
    # to include regular arguments too
    def self.argify(*args)
      regular_args = args.take_while { |arg| !arg.is_a?(Symbol) && !arg.is_a?(Hash) }
      options = optify(*(args - regular_args))

      if options.any?
        regular_args << options
      else
        regular_args
      end
    end

    def self.mzl_set(instance, ivars)
      ivars.each do |k, v|
        instance.instance_variable_set(:"@__mzl_#{k}", v)
      end
    end

    # superclass' mzl thing
    def supermzl
      @supermzl ||= Mzl::Thing.for?(@subject.superclass)
    end

    def initialize(subject)
      raise ArgumentError unless subject.is_a?(Class)

      # the class we will be instantiating
      @subject = subject

      # initialize or inherit?
      unless supermzl
        # this object will hold our DSL methods so we don't make a mess
        @dsl_proxy = DSLProxy.new

        # default parameters for things
        @defaults = {}

        # our name in @subject
        @name = :mzl

        # array of hooks to mzl after instantiating
        @after_init_hooks = []
      else
        # inherit @dsl_proxy, @defaults, @name, and @after_init_hooks from supermzl
        @dsl_proxy = supermzl.instance_variable_get(:@dsl_proxy).clone
        @defaults = JSON.parse(JSON.dump(supermzl.defaults), symbolize_names: true)
        @name = supermzl.instance_variable_get(:@name)
        @after_init_hooks = supermzl.instance_variable_get(:@after_init_hooks).clone
      end

      @defaults.default_proc = proc { |h, k| h[k] = {} }
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
          remove_instance_variable(:@__mzl_new_overridden)
          remove_method(:new) # this is the shim new we defined above
        end
      end
    end

    def delegate(&block)
      raise ArgumentError unless block.is_a?(Proc)
      @dsl_proxy.delegate_proc = block
    end

    def as(new_name)
      @subject.singleton_class.class_exec(@name, new_name) do |old_name, new_name|
        alias_method new_name, old_name
        undef_method(old_name)
      end
      @name = new_name
    end

    # define a DSL method
    def def(sym, *opts, &block)
      raise ArgumentError unless block_given?
      opts = Thing.optify(*opts)
      @dsl_proxy.def(sym, defaults[:def].merge(opts), &block)
    end

    # alias a DSL method, with some optional options
    def alias(new_method, current_method, *opts)
      opts = Thing.optify(*opts)
      # If this is a named child (currently that means Hash)
      # we need to snag the first arg for the name
      pass_first_arg = dsl_proxy.def(current_method)[1][:type] == Hash

      self.def(new_method) do |*_args, &block|
        # Take care of hashes
        args = pass_first_arg ? [_args.shift] : []

        # Then argify
        args += Thing.argify(*_args)

        # Merge opts hash (if provided) into the defaults (if any)
        if args.last.is_a?(Hash) && opts.any?
          args.push(opts.merge(args.pop))
        elsif opts.any?
          args << opts
        end

        begin
          self.send(current_method, *args, &block)
        rescue ArgumentError
          # Try again, but only if we added a opts hash just now
          # (after removing it)
          args.last == opts ? args.pop : raise
          self.send(current_method, *args, &block)
        end
      end
    end

    def attr(sym, *opts)
      opts = Thing.optify(*opts)

      self.def(sym, :persist) do |val = nil|
        raise ArgumentError unless val.nil? || @__mzling

        if val
          instance_variable_set(:"@#{sym}", val)
        else
          instance_variable_get(:"@#{sym}")
        end
      end
    end

    def child(sym, klass, *opts)
      opts = Thing.optify(:persist, *opts)

      # default method for a child: ||= it to a klass.new and mzl a block in it
      opts[:method] ||= Proc.new do |*args, &block|
        # be a attr_reader for a new instance of the child class
        child = ivar_or_assign(:"@#{sym}", klass.mzl.new(Thing.optify(*args)))

        # ensure our child won't lose us
        Thing.mzl_set(child, parent: self, opaque_scope: !!opts[:opaque])

        # mzl an optional block in the child
        child.mzl(&block) if block.is_a?(Proc)

        # and return it, of course
        child
      end

      if opts[:persist]
        # permanent instance method
        @subject.send(:define_method, sym, &opts[:method])
      else
        # mzl-only method
        self.def(sym, opts, &opts[:method])
      end
    end

    def collection(sym, klass, type, *opts)
      opts = Thing.optify(:persist, *opts)
      opts[:plural] ||= "#{sym}s"
      opts[:type] ||= type
      opts[:opaque] ||= false

      find_or_initialize_collection = Proc.new do
        ivar_or_assign(:"@#{opts[:plural]}", opts[:type].new)
      end

      # add a klass.new to the collection after mzling a block in it
      creator = Proc.new do |*args, &block|
        # find or initialize the collection
        collection = instance_exec(&find_or_initialize_collection)
        mzl_opts = {__mzl: {parent: self, opaque_scope: opts[:opaque]}}
        args.last.is_a?(Hash) ? args.last.merge!(mzl_opts) : args << mzl_opts

        if collection.is_a?(Array)
          collection << klass.mzl.new(*args, &block)
        elsif collection.is_a?(Hash)
          key = args.shift
          collection[key] = klass.mzl.new(*args, &block)
        end
      end

      child(sym, klass, method: creator, persist: false, type: opts[:type])

      if opts[:persist]
        @subject.send(:define_method, opts[:plural].to_sym, &find_or_initialize_collection)
      else
        self.def(opts[:plural].to_sym, opts, &find_or_initialize_collection)
      end
    end

    def array(sym, klass, *opts)
      collection(sym, klass, Array, *opts)
    end

    def hash(sym, klass, *opts)
      collection(sym, klass, Hash, *opts)
    end

    def after_init(&block)
      @after_init_hooks << block
    end

    # instance method not class method!
    def new(*args, &block)
      # we will need ourselves later
      _self = self

      # special mzl vars to set on the instance
      mzl_ivars = args.last.delete(:__mzl) if args.last.is_a?(Hash) &&
                                         args.last.has_key?(:__mzl)

      # create an instance of subject
      instance = instantiate(*args)

      # Give it some superpowers
      instance.extend(Mzl::SuperPowers)

      # set the special mzl vars
      Thing.mzl_set(instance, mzl_ivars) if mzl_ivars

      # mzl after_init hooks (by the way, seriously don't use Mzl at runtime)
      @after_init_hooks.each { |hook| exec(instance, &hook) }

      # mzl a block
      instance = block_given? ? exec(instance, &block) : instance
      instance.__after_mzl if instance.respond_to?(:__after_mzl)

      # Give the instance a mzl thing (_self)
      instance.singleton_class.send(:define_method, :mzl) do |opts = {}, &blk|
        _self.exec(self, &blk) if blk.is_a?(Proc)
        _self
      end

      # put the permanent methods on (in case they never call mzl with a block)
      @dsl_proxy.insert_dsl(instance, persist: true)

      # and return it
      instance
    end

    # safely instantiate an object because .arity lies or I'm doing it wrong
    def instantiate(*args)
      _new = subject.respond_to?(:mzl_orig_new) ? :mzl_orig_new : :new

      begin
        subject.send(_new, *args)
      rescue ArgumentError
        subject.send(_new)
      end
    end

    def exec(instance, &block)
      return instance unless block_given?

      # have the dsl proxy execute the block on behalf of that instance
      @dsl_proxy.exec_for(instance, &block)
    end
  end
end
