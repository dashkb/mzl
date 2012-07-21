require 'spec_helper'

describe 'Mzl inheritance' do
  let(:klass) {
    klass = Class.new do
      mzl.override_new
      mzl.defaults[:def][:persist] = true

      mzl.def :yes do
        :yes!
      end

      mzl.def :no, persist: false do
        :no!
      end
    end
    klass
  }

  specify 'happens automatically' do
    subklass = Class.new(klass)

    subklass.new.should respond_to(:yes)
    subklass.new.yes.should == :yes!

    subklass.new.should_not respond_to(:no)
    subklass.new { no.should == :no! }
  end

  specify 'protects superclass' do
    subklass = Class.new(klass) do
      mzl.def :no, persist: true do
        :yes!
      end
    end

    klass.new.should_not respond_to(:no)
    klass.new { no.should == :no! }

    subklass.new.should respond_to(:no)
    subklass.new.no.should == :yes!
  end

  specify 'uses defaults from superclass' do
    klass.mzl.defaults.should_not be_empty

    subklass = Class.new(klass) do
      mzl.def :ok do
        :ok!
      end
    end

    subklass.mzl.defaults.should == klass.mzl.defaults
    subklass.new.should respond_to(:ok)
    subklass.new.ok.should == :ok!
  end

  specify 'can override defaults from superclass' do
    subklass = Class.new(klass) do
      mzl.defaults[:def][:persist] = false
      mzl.def :ok do
        :ok!
      end
    end

    subklass.new.should_not respond_to(:ok)
    subklass.new { ok.should == :ok! }

    subklass.mzl.defaults.should == {def: {persist: false}}
    klass.mzl.defaults.should == {def: {persist: true}}
  end
end