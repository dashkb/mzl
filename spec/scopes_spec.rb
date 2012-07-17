require 'spec_helper'
require 'examples/scopes'

describe Examples::Scopes do
  subject { Examples::Scopes }
  let(:instance) { subject.mzl.new }

  it 'has a calculator child' do
    instance.should respond_to(:calculate)
    instance.calculate.should be_a(Examples::Calculate)

    catch(:calculate) do
      instance.mzl do
        throw :calculate, calculate
      end
    end.should be_a(Examples::Calculate)
  end

  it 'can do math with the calculator child' do
    expect {
      instance.mzl do
        calculate.mzl { add 1, 1 }
      end
    }.to change { instance.calculate.total }.by(2)
  end

  it 'can do math with the calculator child without calling mzl explicitly' do
    expect {
      instance.mzl { calculate { add 1, 4 } }
    }.to change { instance.calculate.total }.by(5)

    expect {
      instance.calculate { add 1, 1 }
    }.to_not raise_exception

    expect {
      instance.calculate.mzl { calculate { add 2, 3 } }
    }
  end
end