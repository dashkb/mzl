 module Mzl
  class DSLProxy
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
    def def(m, opts, &block)
      raise ArgumentError if defs.include?(m)
      @defs[m] = [block, opts]
    end

    # a list of our methods
    def defs
      @defs.keys
    end

    # leave this def on the instance? (so it is accessible without mzl)
    def persist?(m)
      @defs[m][1][:persist]
    end

    # define our DSL methods on the instance's metaclass
    def insert_mzl(instance, filter = {})
      @defs.each do |m, ary|
        blk, opts = ary
        next unless filter.empty? || opts == filter
        instance.singleton_class.send(:define_method, m, &blk)
      end
    end

    # remove all our methods
    def extract_mzl(instance)
      defs.each do |m|
        instance.singleton_class.send(:remove_method, m) unless persist?(m)
      end
    end

    # execute the block against the instance with our methods
    # available.  afterwards, remove the :persist => false ones
    def exec_for(instance, &block)
      insert_mzl(instance)
      instance.instance_exec(&block)
      extract_mzl(instance)

      # return the instance
      instance
    end
  end
end