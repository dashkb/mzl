# methods available to instances that have been mzl'd
module Mzl
  module SuperPowers
    def ivar_or_assign(sym, val)
      ivar = instance_variable_get(sym)
      ivar = instance_variable_set(sym, val) unless ivar
      ivar
    end
  end
end