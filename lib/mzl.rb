require 'mzl/version'

module Mzl
  autoload :Thing, 'mzl/thing'
  autoload :DSLProxy, 'mzl/dsl_proxy'
  autoload :SuperPowers, 'mzl/super_powers'

  module Class
    def mzl(&block)
      @mzl ||= Mzl::Thing.for(self)

      block_given? ? @mzl.new(&block) : @mzl
    end
  end
end

Class.send(:include, Mzl::Class)