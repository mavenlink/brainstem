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

    describe '#keys' do
      it "returns the union of this class's keys with any parent keys" do
        parent_class.configuration['1'] = :a
        parent_class.configuration['2'] = :b

        subclass = Class.new(parent_class)
        subclass.configuration['2'] = :c
        subclass.configuration['3'] = :d

        subsubclass = Class.new(subclass)
        subsubclass.configuration['3'] = :e
        subsubclass.configuration['4'] = :f

        expect(parent_class.configuration.keys).to eq ['1', '2']
        expect(subclass.configuration.keys).to eq ['1', '2', '3']
        expect(subsubclass.configuration.keys).to eq ['1', '2', '3', '4']

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
    end

    describe '#nest!' do
      it 'builds nested objects' do
        parent_class.configuration.nest!('top_level')
        expect(parent_class.configuration['top_level']).to be_a(Brainstem::Concerns::InheritableConfiguration::Configuration)
        parent_class.configuration.nest!('top_level').nest!('next_level')
        expect(parent_class.configuration['top_level']['next_level']).to be_a(Brainstem::Concerns::InheritableConfiguration::Configuration)
      end

      it 'is chainable' do
        parent_class.configuration.nest!('top_level').nest!('sub_one')
        sub_two = parent_class.configuration.nest!('top_level').nest!('sub_two')
        expect(parent_class.configuration['top_level']['sub_one']).to be_a(Brainstem::Concerns::InheritableConfiguration::Configuration)
        expect(parent_class.configuration['top_level']['sub_two']).to be_a(Brainstem::Concerns::InheritableConfiguration::Configuration)
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
        expect(array).to be_a(Brainstem::Concerns::InheritableConfiguration::InheritableAppendSet)
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
  end

  describe '#configuration' do
    it 'is available on the instance' do
      parent_class.configuration['two'] = 2
      expect(parent_class.new.configuration['two']).to eq 2
    end
  end
end
