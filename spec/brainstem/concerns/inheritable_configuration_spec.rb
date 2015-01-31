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

    describe '.nest' do
      it 'builds nested objects' do
        parent_class.configuration.nest('top_level')
        expect(parent_class.configuration['top_level']).to be_a(Brainstem::Concerns::InheritableConfiguration::Configuration)
        parent_class.configuration.nest('top_level').nest('next_level')
        expect(parent_class.configuration['top_level']['next_level']).to be_a(Brainstem::Concerns::InheritableConfiguration::Configuration)
      end

      it 'is chainable' do
        parent_class.configuration.nest('top_level').nest('sub_one')
        sub_two = parent_class.configuration.nest('top_level').nest('sub_two')
        expect(parent_class.configuration['top_level']['sub_one']).to be_a(Brainstem::Concerns::InheritableConfiguration::Configuration)
        expect(parent_class.configuration['top_level']['sub_two']).to be_a(Brainstem::Concerns::InheritableConfiguration::Configuration)
        expect(parent_class.configuration['top_level']['sub_two']).to be sub_two
      end

      it 'inherits nested values' do
        parent_class.configuration.nest('top_level').nest('sub_one')
        parent_class.configuration.nest('top_level').nest('sub_two')
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

        subclass.configuration['top_level']['key'] = 'overriden value'
        subclass.configuration['top_level']['new_key'] = 'new value'
        subclass.configuration['top_level']['sub_one']['sub_one_key1'] = 'overriden nested value'
        subclass.configuration['top_level']['sub_one']['new_key'] = 'new nested value'
        subclass.configuration['top_level'].nest('new_nesting')['key'] = 'hello'

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
        subclass.configuration['top_level'].nest('only_sub')
        subclass.configuration['top_level']['only_sub']['two'] = 2
        expect(subclass.configuration['top_level']['only_sub']['two']).to eq 2
        expect(parent_class.configuration['top_level']['only_sub']).to be_nil
      end
    end
  end
end
