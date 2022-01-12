require "spec_helper"

shared_examples_for Brainstem::QueryStrategies::BaseStrategy do
  let(:strategy) { described_class.new(options) }

  describe "#calculate_per_page" do
    let(:result) { strategy.calculate_per_page }

    [
      # per_page  default_per_page  max_per_page  default_max_per_page  expected   situation                             used
      [       10,               20,          100,                  200,       10,  "per page < max",                     "the per page"],
      [      nil,               20,          100,                  200,       20,  "no per page and default < max",      "the default"],
      [      nil,              200,          100,                  200,      100,  "no per page and default > max",      "the max"],
      [      150,               20,          100,                  200,      100,  "per page > max",                     "the max"],
      [      150,               20,          nil,                  200,      150,  "no max and per page < default max",  "the per page"],
      [      250,               20,          nil,                  200,      200,  "no max and per page > default max",  "the default max"],
    ].each do |per_page, default_per_page, max_per_page, default_max_per_page, expected, situation, used|
      describe "when #{situation}" do
        let(:options) {
          {
            params: {
              per_page: per_page,
            },
            default_per_page: default_per_page,
            default_max_per_page: default_max_per_page,
            max_per_page: max_per_page,
          }
        }

        it "uses #{used}" do
          expect(result).to eq(expected)
        end
      end
    end
  end
end
