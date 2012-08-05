require 'spec_helper'

describe 'scoping' do
  let(:child_class) { Class.new {
    mzl.child(:the_child, Class.new)
    mzl.def(:inner_method) { throw(:the_instance, self) }
  }}

  let(:parent_class) {
    klass = Class.new { mzl.override_new }
    klass.mzl.def(:parent_method) { throw(:the_instance, self) }
    klass
  }

  describe 'method_missing' do
    context 'during mzl' do
      context 'with :opaque' do
        before(:each) { parent_class.mzl.child(:the_child, child_class, :opaque) }

        it 'behaves normally' do
          expect {
            parent_class.new { the_child { parent_method} }
          }.to raise_exception(NameError)
        end
      end

      context 'without :opaque' do
        before(:each) { parent_class.mzl.child(:the_child, child_class) }

        specify 'sends message to the innermost parent that can respond' do
          # from two deep to top
          catch(:the_instance) {
            parent_class.new { the_child { parent_method } }
          }.should be_a(parent_class)

          # from two deep to one deep
          catch(:the_instance) {
            parent_class.new { the_child { the_child { inner_method } } }
          }.should be_a(child_class)

          # from two deep to top
          catch(:the_instance) {
            parent_class.new { the_child { the_child { parent_method } } }
          }.should be_a(parent_class)
        end

        specify 'calls super when no parent can respond' do
          # mp quiz: why can't I `def child_class.method_missing` here?
          child_class.send(:define_method, :method_missing) do |m|
            raise "NoMethodError or something: #{m}"
          end

          expect {
            parent_class.new { the_child { not_a_method } }
          }.to raise_exception('NoMethodError or something: not_a_method')
        end
      end
    end 

    context 'after mzl' do
      before(:each) { parent_class.mzl.child(:the_child, child_class) }

      specify 'exhibits normal behavior' do
        instance = parent_class.new { the_child { @foo = :bar } }

        instance.the_child.should be_a(child_class)
        instance.the_child.instance_variable_get(:@foo).should == :bar

        expect {
          instance.parent_method
        }.to raise_exception(NoMethodError)

        expect {
          instance.the_child.inner_method
        }.to raise_exception(NoMethodError)
      end
    end
  end
end