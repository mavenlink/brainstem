require 'spec_helper'

describe Brainstem do
  describe "default_namespace attribute" do
    it "can be set and read" do
      Brainstem.default_namespace = "something"
      Brainstem.default_namespace.should eq("something")
    end

    it "returns 'none' if unset" do
      Brainstem.default_namespace.should eq("none")
    end
  end

  describe "presenter collection method" do
    it "returns an instance of PresenterCollection" do
      Brainstem.presenter_collection.should be_a(Brainstem::PresenterCollection)
    end

    it "accepts a namespace" do
      Brainstem.presenter_collection("v1").should be_a(Brainstem::PresenterCollection)
      Brainstem.presenter_collection("v1").should_not eq(Brainstem.presenter_collection)
    end
  end
end
