# frozen_string_literal: true

require 'rspec'

describe 'Contexts' do
  context 'when' do
    context 'there' do
      context 'are' do
        context 'many' do
          context 'levels' do
            context 'of' do
              context 'nested' do
                context 'contexts' do
                  it "doesn't break the extension" do
                    expect('Hello text explorer!').to be_a(String)
                  end
                end
              end
            end
          end
        end

        context 'fewer levels of nested contexts' do
          it do
            expect('Hello again text explorer!').to be_a(String)
          end
        end
      end
    end
  end

  shared_examples_for "an even number" do
    it "is divisible by 2" do
      expect(value % 2).to be 0
    end
  end

  shared_context "even number" do
    let(:value) { 4 }
  end

  shared_context "odd number" do
    let(:value) { 5 }
  end

  context 'with shared examples' do
    shared_examples_for "an odd number" do
      it "is not divisible by 2" do
        expect(value % 2).to_not be 0
      end
    end

    context 'when number is even' do
      include_context "even number"

      it_behaves_like "an even number"
    end

    context 'when number is odd' do
      include_context "odd number"

      it_behaves_like "an odd number"
    end
  end
end
