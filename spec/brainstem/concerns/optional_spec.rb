require 'spec_helper'
require 'brainstem/concerns/optional'

describe Brainstem::Concerns::Optional do
  let(:optional_class) do
    Class.new do
      include Brainstem::Concerns::Optional
    end
  end

  context "when options are not passed" do
    it "raises no error" do
      expect { optional_class.new }.not_to raise_error
    end
  end

  context "when options are passed" do
    context "when option is whitelisted" do
      before do
        stub.any_instance_of(optional_class).valid_options { [:thing] }
      end

      context "when an accessor exists" do
        before do
          mock.any_instance_of(optional_class).thing=("blah")
        end

        it "passes the option to the accessor" do
          optional_class.new(thing: "blah")
        end
      end

      context "when no accessor exists" do
        it "raises an error" do
          expect { optional_class.new(thing: "blah") }.to \
            raise_error NoMethodError
        end
      end
    end

    context "when option is not whitelisted" do
      it "does not send the symbol" do
        dont_allow.any_instance_of(optional_class).other_thing
        expect { optional_class.new(other_thing: "nope") }.not_to raise_error
      end
    end
  end
end
