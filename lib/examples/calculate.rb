module Examples
  class Calculate
    def initialize
      @total = 0
    end

    mzl.def :total, persist: true do
      @total
    end

    mzl.def :add do |*numbers|
      @total += numbers.inject(:+)
    end
  end
end
