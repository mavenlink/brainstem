require 'spec_helper'
require 'brainstem/presenter_validator'

describe Brainstem::PresenterValidator do
  let(:presenter_class) do
    Class.new(Brainstem::Presenter) do
      presents Workspace

      preload :lead_user

      conditionals do
        model :title_is_hello, lambda { |model| model.title == 'hello' }, 'visible when the title is hello'
        request :user_is_bob, lambda { current_user == 'bob' }, 'visible only to bob'
      end

      fields do
        field :title, :string
        field :description, :string
        field :updated_at, :datetime
        field :secret, :string, 'a secret, via secret_info',
              via: :secret_info,
              if: [:user_is_bob, :title_is_hello]

        with_options if: :user_is_bob do
          field :bob_title, :string, 'another name for the title, only for Bob',
                via: :title
        end
      end

      associations do
        association :tasks, Task, 'The Tasks in this Workspace',
                    restrict_to_only: true
        association :lead_user, User, 'The user who runs this Workspace'
        association :subtasks, Task, 'Only Tasks in this Workspace that are subtasks',
                    dynamic: lambda { |workspace| workspace.tasks.where('parent_id IS NOT NULL') }
      end
    end
  end

  let(:validator) { Brainstem::PresenterValidator.new(presenter_class) }

  it 'should be valid' do
    expect(presenter_class.configuration[:preloads]).not_to be_empty
    expect(presenter_class.configuration[:fields]).not_to be_empty
    expect(presenter_class.configuration[:associations]).not_to be_empty
    expect(validator).to be_valid
  end

  describe 'validating preload' do
    it 'adds an error if the requested preload does not exist on the presented class' do
      presenter_class.preload :foo
      expect(validator).not_to be_valid
      expect(validator.errors[:preload]).to eq ["not all presented classes respond to 'foo'"]
    end

    it 'adds an error if the requested preload does not exist on only one of the presented classes' do
      presenter_class.presents User
      expect(validator).not_to be_valid
      expect(validator.errors[:preload]).to eq ["not all presented classes respond to 'lead_user'"]
    end
  end

  describe 'validating associations' do
    it 'adds an error for any field that is not on all presented classes' do
      presenter_class.associations do
        association :foo, Workspace
        association :bar, Workspace
      end

      expect(validator).not_to be_valid
      expect(validator.errors[:associations]).to eq ["'foo' is not valid because not all presented classes respond to 'foo'",
                                                     "'bar' is not valid because not all presented classes respond to 'bar'"]
    end

    it 'adds an error for any association that does not have a known presenter' do
      class NewConcept; end

      presenter_class.associations do
        association :tasks, NewConcept
      end

      expect(validator).not_to be_valid
      expect(validator.errors[:associations]).to eq ["'tasks' is not valid because no presenter could be found for the NewConcept class"]
    end
  end

  describe 'validating fields' do
    it 'adds an error for any field that is not on all presented classes' do
      presenter_class.fields do
        field :foo, :string
        field :bar, :integer
      end

      expect(validator).not_to be_valid
      expect(validator.errors[:fields]).to eq ["'foo' is not valid because not all presented classes respond to 'foo'",
                                               "'bar' is not valid because not all presented classes respond to 'bar'"]
    end

    it 'errors when one of the presented classes is missing a field' do
      presenter_class.presents User
      expect(validator).not_to be_valid
      expect(validator.errors[:fields]).to be_present
    end

    it 'supports :via' do
      presenter_class.fields do
        field :foo, :string, via: :title
      end

      expect(validator).to be_valid
    end

    it 'supports dynamic fields' do
      presenter_class.fields do
        field :foo, :string, dynamic: lambda { 2 }
      end

      expect(validator).to be_valid
    end

    it 'supports nested fields' do
      presenter_class.fields do
        fields :permissions do
          field :title, :string
        end
      end

      expect(validator).to be_valid

      presenter_class.fields do
        fields :permissions do
          field :missing, :string
        end
      end

      expect(validator).not_to be_valid
      expect(validator.errors[:fields]).to eq ["'missing' is not valid because not all presented classes respond to 'missing'"]
    end

    it "checks that any 'if' option has a matching conditional(s)" do
      expect(presenter_class.configuration[:conditionals][:title_is_hello]).to be_present

      presenter_class.fields do
        field :title, :string, if: :title_is_hello
      end

      expect(validator).to be_valid

      presenter_class.fields do
        field :title, :string, if: [:title_is_hello, :wat]
      end

      expect(validator).not_to be_valid
      expect(validator.errors[:fields]).to eq ["'title' is not valid because one or more of the specified conditionals does not exist"]
    end

    it "checks conditionals on nested fields too" do
      presenter_class.fields do
        fields :permissions do
          field :title, :string, if: [:title_is_hello, :wat]
        end
      end

      expect(validator).not_to be_valid
      expect(validator.errors[:fields]).to eq ["'title' is not valid because one or more of the specified conditionals does not exist"]
    end
  end

  specify 'all spec presenters should be valid' do
    Brainstem.presenter_collection.presenters.each do |name, klass|
      expect(Brainstem::PresenterValidator.new(klass)).to be_valid
    end
  end
end
