require "spec_helper"

describe Brainstem do
  describe "default_namespace attribute" do
    it "can be set and read" do
      Brainstem.default_namespace = "something"
      expect(Brainstem.default_namespace).to eq("something")
    end

    it "returns 'none' if unset" do
      expect(Brainstem.default_namespace).to eq("none")
    end
  end

  describe "presenter collection method" do
    it "returns an instance of PresenterCollection" do
      expect(Brainstem.presenter_collection).to be_a(Brainstem::PresenterCollection)
    end

    it "accepts a namespace" do
      expect(Brainstem.presenter_collection("v1")).to be_a(Brainstem::PresenterCollection)
      expect(Brainstem.presenter_collection("v1")).not_to eq(Brainstem.presenter_collection)
    end
  end
end
