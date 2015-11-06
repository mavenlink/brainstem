require 'spec_helper'
require 'brainstem/concerns/inheritable_configuration'

describe Brainstem::Concerns::InheritableConfiguration do
  let(:parent_class) do
    Class.new do
      include Brainstem::Concerns::InheritableConfiguration
    end
  end

  describe '.configuration' do
    it 'is inherited' do
      expect(parent_class.configuration['empty']).to be_nil
      parent_class.configuration['two'] = 2
      parent_class.configuration['five'] = 5
      expect(parent_class.configuration['two']).to eq 2
      expect(parent_class.configuration['five']).to eq 5

      subclass = Class.new(parent_class)
      expect(subclass.configuration['empty']).to be_nil
      expect(subclass.configuration['two']).to eq 2
      expect(subclass.configuration['five']).to eq 5

      subclass.configuration['two'] = 3
      subclass.configuration['ten'] = 10
      expect(subclass.configuration['empty']).to be_nil
      expect(subclass.configuration['two']).to eq 3
      expect(subclass.configuration['five']).to eq 5
      expect(subclass.configuration['ten']).to eq 10

      expect(parent_class.configuration['two']).to eq 2
      expect(parent_class.configuration['five']).to eq 5
      expect(parent_class.configuration['ten']).to be_nil
    end

    it "does not inherit nonheritable keys" do
      expect(parent_class.configuration['nonheritable']).to be_nil
      parent_class.configuration.nonheritable! :nonheritable
      parent_class.configuration['nonheritable'] = "parent"
      expect(parent_class.configuration['nonheritable']).to eq "parent"

      subclass = Class.new(parent_class)
      expect(subclass.configuration['nonheritable']).to be_nil

      subclass.configuration['nonheritable'] = "child"

      subsubclass = Class.new(subclass)
      expect(subsubclass.configuration['nonheritable']).to be_nil
    end

    describe '#keys and #to_h' do
      let(:subclass) { Class.new(parent_class) }
      let(:subsubclass) { Class.new(subclass) }

      before do
        parent_class.configuration['1'] = :a
        parent_class.configuration['2'] = :b

        subclass.configuration['2'] = :c
        subclass.configuration['3'] = :d

        subsubclass.configuration['3'] = :e
        subsubclass.configuration['4'] = :f
      end

      it "returns the union of this class's keys with any parent keys" do
        expect(parent_class.configuration.keys).to eq ['1', '2']
        expect(parent_class.configuration.to_h).to eq({ '1' => :a, '2' => :b })
        expect(subclass.configuration.keys).to eq ['1', '2', '3']
        expect(subclass.configuration.to_h).to eq({ '1' => :a, '2' => :c, '3' => :d })
        expect(subsubclass.configuration.keys).to eq ['1', '2', '3', '4']
        expect(subsubclass.configuration.to_h).to eq({ '1' => :a, '2' => :c, '3' => :e, '4' => :f })

        # it doesn't mutate storage
        subclass.configuration.to_h['1'] = :new
        subclass.configuration.to_h['2'] = :new
        expect(subclass.configuration['1']).to eq :a
        expect(subclass.configuration['2']).to eq :c
        expect(parent_class.configuration['1']).to eq :a
        expect(parent_class.configuration['2']).to eq :b

        expect(parent_class.configuration['1']).to eq :a
        expect(parent_class.configuration['2']).to eq :b
        expect(parent_class.configuration['3']).to be_nil
        expect(subclass.configuration['1']).to eq :a
        expect(subclass.configuration['2']).to eq :c
        expect(subclass.configuration['3']).to eq :d
        expect(subclass.configuration['4']).to be_nil
        expect(subsubclass.configuration['1']).to eq :a
        expect(subsubclass.configuration['2']).to eq :c
        expect(subsubclass.configuration['3']).to eq :e
        expect(subsubclass.configuration['4']).to eq :f
      end

      it "does not return nonheritable keys in the parent" do
        parent_class.configuration.nonheritable! 'nonheritable'
        parent_class.configuration['nonheritable'] = "why yes, I am nonheritable"
        expect(subclass.configuration.keys).not_to include 'nonheritable'

        expect(subclass.configuration.to_h.keys).not_to include 'nonheritable'
        expect(subclass.configuration.has_key?('nonheritable')).to eq false
      end
    end

    describe "#fetch" do
      let(:config)    { parent_class.configuration }
      let(:my_block)  { Proc.new { nil } }

      before do
        parent_class.configuration["my_key"] = "yep"
      end

      context "when key is found" do
        it "returns the key" do
          expect(config.fetch("my_key")).to eq "yep"
        end
      end

      context "when key is not found" do
        context "when default or block not given" do
          it "raises a KeyError exception" do
            expect { config.fetch("fake_key") }.to raise_exception KeyError
          end
        end

        context "when block given" do
          before do
            mock(my_block).call { "hey" }
          end

          it "evals and returns the block" do
            expect(config.fetch("fake_key", &my_block)).to eq "hey"
          end
        end

        context "when default given" do
          it "returns the default" do
            expect(config.fetch("fake_key", "hey")).to eq "hey"
          end
        end

        context "when default and block given" do
          before do
            mock(my_block).call("hey") { "sup" }
          end

          it "evals and returns the block, passing it the default" do
            expect(config.fetch("fake_key", "hey", &my_block)).to eq "sup"
          end
        end
      end
    end

    describe '#nest!' do
      it 'builds nested objects' do
        parent_class.configuration.nest!('top_level')
        expect(parent_class.configuration['top_level']).to be_a(Brainstem::DSL::Configuration)
        parent_class.configuration.nest!('top_level').nest!('next_level')
        expect(parent_class.configuration['top_level']['next_level']).to be_a(Brainstem::DSL::Configuration)
      end

      it 'is chainable' do
        parent_class.configuration.nest!('top_level').nest!('sub_one')
        sub_two = parent_class.configuration.nest!('top_level').nest!('sub_two')
        expect(parent_class.configuration['top_level']['sub_one']).to be_a(Brainstem::DSL::Configuration)
        expect(parent_class.configuration['top_level']['sub_two']).to be_a(Brainstem::DSL::Configuration)
        expect(parent_class.configuration['top_level']['sub_two']).to be sub_two
      end

      it 'inherits nested values' do
        parent_class.configuration.nest!('top_level').nest!('sub_one')
        parent_class.configuration.nest!('top_level').nest!('sub_two')
        parent_class.configuration['top_level']['key'] = 'value'
        parent_class.configuration['top_level']['key2'] = 'value2'
        parent_class.configuration['top_level']['sub_one']['sub_one_key1'] = 'sub_one_value1'
        parent_class.configuration['top_level']['sub_one']['sub_one_key2'] = 'sub_one_value2'
        parent_class.configuration['top_level']['sub_two']['sub_two_key'] = 'sub_two_value'

        expect(parent_class.configuration['top_level']['key']).to eq 'value'
        expect(parent_class.configuration['top_level']['sub_one']['sub_one_key1']).to eq 'sub_one_value1'

        subclass = Class.new(parent_class)
        expect(subclass.configuration['top_level']['key']).to eq 'value'
        expect(subclass.configuration['top_level']['key2']).to eq 'value2'
        expect(subclass.configuration['top_level']['sub_one']['sub_one_key1']).to eq 'sub_one_value1'
        expect(subclass.configuration['top_level']['sub_one']['sub_one_key2']).to eq 'sub_one_value2'
        expect(subclass.configuration['top_level']['sub_two']['sub_two_key']).to eq 'sub_two_value'

        # These should have no affect
        subclass.configuration['top_level'].nest!('sub_one')
        subclass.configuration['top_level'].nest!('sub_two')

        # This should add a new nested configuration
        subclass.configuration['top_level'].nest!('new_nesting')['key'] = 'hello'

        subclass.configuration['top_level']['key'] = 'overriden value'
        subclass.configuration['top_level']['new_key'] = 'new value'
        subclass.configuration['top_level']['sub_one']['sub_one_key1'] = 'overriden nested value'
        subclass.configuration['top_level']['sub_one']['new_key'] = 'new nested value'

        expect(subclass.configuration['top_level']['key']).to eq 'overriden value'
        expect(subclass.configuration['top_level']['key2']).to eq 'value2'
        expect(subclass.configuration['top_level']['new_key']).to eq 'new value'
        expect(subclass.configuration['top_level']['sub_one']['sub_one_key1']).to eq 'overriden nested value'
        expect(subclass.configuration['top_level']['sub_one']['sub_one_key2']).to eq 'sub_one_value2'
        expect(subclass.configuration['top_level']['sub_one']['new_key']).to eq 'new nested value'
        expect(subclass.configuration['top_level']['sub_two']['sub_two_key']).to eq 'sub_two_value'
        expect(subclass.configuration['top_level']['new_nesting']['key']).to eq 'hello'

        expect(parent_class.configuration['top_level']['key']).to eq 'value'
        expect(parent_class.configuration['top_level']['key2']).to eq 'value2'
        expect(parent_class.configuration['top_level']['new_key']).to be_nil
        expect(parent_class.configuration['top_level']['sub_one']['sub_one_key1']).to eq 'sub_one_value1'
        expect(parent_class.configuration['top_level']['sub_one']['sub_one_key2']).to eq 'sub_one_value2'
        expect(parent_class.configuration['top_level']['sub_one']['new_key']).to be_nil
        expect(parent_class.configuration['top_level']['sub_two']['sub_two_key']).to eq 'sub_two_value'
        expect(parent_class.configuration['top_level']['new_nesting']).to be_nil

        # Adding an attribute to parent later will show up in sub
        parent_class.configuration['top_level']['added_later'] = 5
        expect(parent_class.configuration['top_level']['added_later']).to eq 5
        expect(subclass.configuration['top_level']['added_later']).to eq 5

        # Changing an attribute to parent later will show up in sub
        parent_class.configuration['top_level']['added_later'] = 6
        expect(parent_class.configuration['top_level']['added_later']).to eq 6
        expect(subclass.configuration['top_level']['added_later']).to eq 6

        # Overriding an attribute in sub only affects sub.
        subclass.configuration['top_level']['added_later'] = 5
        expect(parent_class.configuration['top_level']['added_later']).to eq 6
        expect(subclass.configuration['top_level']['added_later']).to eq 5

        # Can add nesting to sub only
        subclass.configuration['top_level'].nest!('only_sub')
        subclass.configuration['top_level']['only_sub']['two'] = 2
        expect(subclass.configuration['top_level']['only_sub']['two']).to eq 2
        expect(parent_class.configuration['top_level']['only_sub']).to be_nil

        # Go even deeper
        subsubclass = Class.new(subclass)
        expect(subsubclass.configuration['top_level']['only_sub']['two']).to eq 2
        subsubclass.configuration['top_level']['only_sub']['two'] = 3
        expect(subsubclass.configuration['top_level']['only_sub']['two']).to eq 3
        expect(subclass.configuration['top_level']['only_sub']['two']).to eq 2
      end

      it 'will not override nested values' do
        parent_class.configuration.nest!('top_level').nest!('sub_one')
        subclass = Class.new(parent_class)
        expect(lambda { subclass.configuration['top_level']['sub_one'] = 2 }).to raise_error('You cannot override a nested value')
      end
    end

    describe '#array!' do
      let!(:array) { parent_class.configuration.array!('list') }

      it 'builds an InheritableAppendSet' do
        expect(array).to be_a(Brainstem::DSL::Configuration::InheritableAppendSet)
        expect(parent_class.configuration.array!('list')).to be array
      end

      it 'is inherited' do
        parent_class.configuration['list'] << '2'
        parent_class.configuration['list'].push 3

        subclass = Class.new(parent_class)
        expect(parent_class.configuration['list'].to_a).to eq ['2', 3]
        expect(subclass.configuration['list'].to_a).to eq ['2', 3]

        parent_class.configuration['list'].push 4
        expect(parent_class.configuration['list'].to_a).to eq ['2', 3, 4]
        expect(subclass.configuration['list'].to_a).to eq ['2', 3, 4]

        subclass.configuration['list'].push 5
        expect(parent_class.configuration['list'].to_a).to eq ['2', 3, 4]
        expect(subclass.configuration['list'].to_a).to eq ['2', 3, 4, 5]

        parent_class.configuration['list'].push 6
        expect(parent_class.configuration['list'].to_a).to eq ['2', 3, 4, 6]
        expect(subclass.configuration['list'].to_a).to eq ['2', 3, 4, 6, 5]
      end

      it 'will not override arrays' do
        subclass = Class.new(parent_class)
        expect(lambda { subclass.configuration['list'] = 2 }).to raise_error('You cannot override an inheritable array once set')
      end
    end

    describe "#nonheritable!" do
      it "adds the key to the nonheritable attributes list" do
        parent_class.configuration.nonheritable! :nonheritable
        expect(parent_class.configuration.nonheritable_keys).to eq ["nonheritable"]
      end

      it "dedupes" do
        parent_class.configuration.nonheritable! :nonheritable
        parent_class.configuration.nonheritable! :nonheritable
        expect(parent_class.configuration.nonheritable_keys).to eq ["nonheritable"]
      end
    end
  end

  describe '#configuration' do
    it 'is available on the instance' do
      parent_class.configuration['two'] = 2
      expect(parent_class.new.configuration['two']).to eq 2
    end
  end
end
