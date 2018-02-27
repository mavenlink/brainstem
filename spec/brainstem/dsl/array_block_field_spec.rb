require 'spec_helper'
require 'brainstem/dsl/field'

describe Brainstem::DSL::ArrayBlockField do
  let(:name)         { :tasks }
  let(:type)         { :array }
  let(:description)  { 'the title of this model' }
  let(:options)      { { info: description } }
  let(:nested_field) { Brainstem::DSL::ArrayBlockField.new(name, type, options) }
  let(:model)        { Workspace.find(1) }
  let(:tasks)        { Task.where(workspace_id: model.id).order(:id).to_a }

  before do
    expect(tasks).to_not be_empty
    expect(nested_field.configuration.keys).to be_empty

    # Add sub fields to the nested array field.
    nested_field.configuration[:name] = Brainstem::DSL::Field.new(:name, type, {})
    nested_field.configuration[:parent_name] = Brainstem::DSL::Field.new(:parent_name, type,
      dynamic: -> (model) { model.parent.try(:name) }
    )
    nested_field.configuration[:secret] = Brainstem::DSL::Field.new(:secret, type,
      via: :secret_info,
      use_parent_value: false
    )

    expect(nested_field.configuration.keys).to eq(%w(name parent_name secret))
  end

  describe '#run_on' do
    let(:context)              { { } }
    let(:helper_instance)      { Object.new }
    let(:presented_field_data) {
      tasks.map do |task|
        { 'name' => task.name, 'parent_name' => task.parent.try(:name), 'secret' => model.secret_info }
      end
    }

    it 'returns an array of hashes with sub nested properties' do
      expect(nested_field.run_on(model, context)).to eq(presented_field_data)
    end
  end
end
