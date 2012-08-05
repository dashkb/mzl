require 'spec_helper'

describe 'Class.mzl' do
  let(:klass) { Class.new { mzl.override_new } }

  describe '.after_init' do
    before(:each) do
      klass.mzl.after_init do
        raise if @foo
        @foo = 0
      end

      klass.mzl.after_init { @foo += 1 }
      klass.mzl.after_init { @foo += 1 }
    end


    it 'can specify multiple blocks, to be run in order' do
      klass.new.instance_variable_get(:@foo).should == 2
    end

    it 'is inherited' do
      Class.new(klass).new.instance_variable_get(:@foo).should == 2
    end
  end
end