require "spec_helper"

shared_examples_for Brainstem::QueryStrategies::BaseStrategy do
  let(:strategy) { described_class.new(options) }

  describe "#calculate_per_page" do
    let(:result) { strategy.calculate_per_page }

    [
      # per_page  default_per_page  max_per_page  default_max_per_page  expected   message
      [       10,               20,          100,                  200,       10,  "per page < max"],
      [      nil,               20,          100,                  200,       20,  "no per page and default < max"],
      [      nil,              200,          100,                  200,      100,  "no per page and default > max"],
      [      150,               20,          100,                  200,      100,  "per page > max"],
      [      150,               20,          nil,                  200,      150,  "no max and per page < default max"],
      [      250,               20,          nil,                  200,      200,  "no max and per page > default max"],
    ].each do |per_page, default_per_page, max_per_page, default_max_per_page, expected, message|
      describe "for '#{message}'" do
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

        it "calculates the expected result'" do
          expect(result).to eq(expected)
        end
      end
    end
  end
end
