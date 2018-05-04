require 'spec_helper'
require 'brainstem/preloader'

describe Brainstem::Preloader do
  let(:models)        { Array.new }
  let(:preloads)      { Array.new }
  let(:reflections)   { Array.new }
  let(:args)          { [ models, preloads, reflections ] }
  let!(:preloader)    { Brainstem::Preloader.new(*args) }

  describe ".preload" do
    it "creates a new instance, passing args and calls it" do
      preloader = mock(Object.new).call
      mock(Brainstem::Preloader).new(anything, anything, anything) { preloader }
      Brainstem::Preloader.preload(*args)
    end
  end

  describe "#call" do
    it "cleans" do
      mock(preloader).clean!
      preloader.send(:call)
    end

    it "preloads" do
      mock(preloader).preload!
      preloader.send(:call)
    end
  end

  describe "#clean!" do
    it "dedupes the associations" do
      mock(preloader).dedupe!
      preloader.send(:clean!)
    end

    it "removes unreflected preloads" do
      mock(preloader).remove_unreflected_preloads!
      preloader.send(:clean!)
    end
  end

  describe "#dedupe!" do
    before do
      preloader.send(:dedupe!)
    end

    describe "conversion" do
      let(:preloads) { [ :workspaces, { posts: :users }  ] }

      it "converts all non-hash keys to strings" do
        expect(preloader.valid_preloads.keys).not_to include :workspaces
        expect(preloader.valid_preloads.keys).to include "workspaces"
      end

      it "converts all root hash keys to strings" do
        expect(preloader.valid_preloads.keys).not_to include :posts
        expect(preloader.valid_preloads.keys).to include "posts"
      end

      it "does not convert nested objects to strings" do
        expect(preloader.valid_preloads["posts"]).to eq [:users]
      end
    end

    describe "combination" do
      let(:preloads) { [
        { :workspaces => :other_things },
        { workspaces: :things },
        { posts: { users: "posts" } },
        { posts: { users: "subjects" } },
      ] }

      it "combines root-level keys" do
        expect(preloader.valid_preloads["workspaces"]).to eq [:other_things, :things]
      end

      it "does not combine non-root keys" do
        expect(preloader.valid_preloads["posts"].count).to eq 2
        expect(preloader.valid_preloads["posts"].map(&:keys).flatten).to eq [:users, :users]
      end
    end
  end

  describe "#remove_unreflected_preloads!" do
    before do
      stub(preloader).dedupe!

      # This is a little bit contortionist, but this is the only way to set
      # this without running dedupe!
      preloader.instance_variable_set(:@valid_preloads, { users: [], posts: [] })
      preloader.send(:remove_unreflected_preloads!)
    end

    context "when preload in the list of reflections" do
      let(:reflections) { { "users" => [], "posts" => [] } }

      it "keeps it" do
        expect(preloader.valid_preloads.keys).to eq [:users, :posts]
      end
    end

    context "when preload not in the list of reflections" do
      let(:reflections) { { "users" => [] } }

      it "rejects it" do
        expect(preloader.valid_preloads.keys).to eq [:users]
        expect(preloader.valid_preloads.keys).not_to include :posts
      end
    end
  end

  describe "#preload!" do
    let(:preload_method) { Object.new }
    let(:valid_preloads) { { users: [], posts: [] } }

    before do
      preloader.instance_variable_set(:@valid_preloads, valid_preloads)
      preloader.preload_method = preload_method
    end

    it "calls the preload method with its models and valid preloads" do
      mock(preload_method).call(is_a(Array), is_a(Hash)) do |*args|
        expect(args).to eq [models, valid_preloads]
      end

      preloader.send(:preload!)
    end
  end
end
