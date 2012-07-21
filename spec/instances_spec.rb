require 'spec_helper'

describe 'Mzl instances' do
  require 'examples/calculate'
  let(:klass) { Examples::Calculate }

  it 'should not respond to DSL methods' do
    klass.mzl.new.should_not respond_to(:add)
  end

  it 'should respond to normal instance methods' do
    klass.mzl.new.total.should == 0

    catch(:total) do
      klass.mzl.new do
        throw(:total, total)
      end
    end.should == 0
  end

  it 'should put two and two together' do
    klass.mzl.new do
      add 2, 2
    end.total.should == 4
  end

  it 'should have a mzl thing' do
    instance = klass.mzl.new
    instance.should respond_to(:mzl)
    instance.mzl.should be_a(Mzl::Thing)
  end

  it 'can use the mzl thing to call dsl methods later' do
    instance = klass.mzl.new
    instance.should_not respond_to(:add)
    expect {
      instance.mzl do
        add 1, 1, 1, 1
      end
    }.to change { instance.total }.by(4)
  end
end