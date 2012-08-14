require 'spec_helper'

describe 'Class.mzl.delegate' do
  let(:klass) { Class.new {
    mzl.override_new
    mzl.delegate { @delegate }

    def initialize(delegate)
      @delegate = delegate
    end
  }}

  it 'expects a block returning a delegate object when instance_execd' do
    expect {
      instance = klass.new(:srsly?) do
        missing_method
      end
    }.to raise_exception(
      NoMethodError,
      %{undefined method `missing_method' for :srsly?:Symbol}
    )
  end

  it 'forwards missing methods to the delegate' do
    delegate = Class.new {
      def missing_method; @mzl_was_here = true; end
    }.new

    instance = klass.new(delegate) do
      missing_method
    end

    delegate.instance_variable_get(:@mzl_was_here).
      should == true
  end
end
