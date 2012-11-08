require 'spec_helper'

describe ApiPresenter do
  describe "default_namespace attribute" do
    it "can be set and read" do
      ApiPresenter.default_namespace = "something"
      ApiPresenter.default_namespace.should eq("something")
    end

    it "returns 'none' if unset" do
      ApiPresenter.default_namespace.should eq("none")
    end
  end

  describe "presenter collection method" do
    it "returns an instance of PresenterCollection" do
      ApiPresenter.presenter_collection.should be_a(ApiPresenter::PresenterCollection)
    end

    it "accepts a namespace" do
      ApiPresenter.presenter_collection("v1").should be_a(ApiPresenter::PresenterCollection)
      ApiPresenter.presenter_collection("v1").should_not eq(ApiPresenter.presenter_collection)
    end
  end
end