# Filtering/Searching Query Strategies

Traditionally Brainstem has ignored all filters if you defined a `search` block in your presenter.
Brainstem relies on your search implementation to do any necessary filtering. A downside of this is that you may have to
implement your filters twice: once inside your presenters and once inside
your searching solution. This causes extra work, particularly for complex queries and associations that the Brainstem DSL
is well equipped to handle.

The current version of Brainstem offers a beta feature for allowing both searching and filtering to take place. To enable it,
add the following to your presenter:

```ruby
query_strategy :filter_and_search
```

Utilizing this strategy will enable Brainstem to take the intersection of your search results and your filter results,
effectively giving you the best of both worlds: fast, efficient searching using something like ElasticSearch and in depth
ActiveRecord filtering provided by Brainstem.

You must take the following important notes into account when using the `filter_and_search` query strategy:

- Your search block should behave the same as it always has: it should return an array where the first element is an array
  of model ids and the second element is the total number of matched records.
- This works by retrieving ALL of the possible ids from both searching and filtering and then taking the intersection
  of those two sets, up to 10,000 possible results. This means Brainstem will send your search block a `limit` of
  10,000 and an `offset` of 0. As this could have potential performance implications for your API you should make sure
  you performance test this before deploying to a production environment.
- If you have less than 10,000 possible results you shouldn't have to worry about ordering, because the order will
  be applied in Brainstem on the intersection of filter and search results. However, if there is more than 10,000 your
  searching implementation *must* perform the same ordering as your Brainstem filter. Otherwise the 10,000 results
  from the search might not be the same 10,000 from the filter, and the intersection of the two would be incorrect.

The reason we need to request ALL ids is so we can get the correct count of possible results. Without doing this pagination
would not work properly (there would be no way of knowing the total number of pages). This has some obvious performance
implications, which is why we have limited the total number of possible results to 10,000.

This is not a perfect solution for all situations, which is why all presenters will default to the old behavior. You
should only use the `filter_and_search` strategy if you've determined that:

A.) Your API will still be fast enough when there are 10,000 possible results.

B.) It's not critical for the user to be able to retrieve ALL possible results when searching.

C.) It's actually important for your API that it support Brainstem filters and searching at the same time.

# Other strategies

- The default strategy is `filter_or_search` and is the same behavior that Brainstem has historically employed.

# Implementing a strategy

If you have a different filtering or searching strategy you would like to employ, you can create a strategy class
in `lib/brainstem/query_strategies`. Your class should inherit from `BaseStrategy` and implement an `execute` method.
The `execute` method should accept a current scope and return an array of models and the count of all possible modes.

Example:

```ruby
module Brainstem
  module QueryStrategies
    class MyAwesomeFilterStrat < BaseStrategy
      def execute(scope)
        scope = do_something_awesome(scope)
        count = scope.count
        scope = paginate(scope)
        [scope.to_a, count]
      end
    end
  end
end
```

You should then add the logic for using that strategy in the `strategy` method of `PresenterCollection`.

Example:

```ruby
def strategy(options, scope)
  strat = if options[:primary_presenter].configuration.has_key? :query_strategy
            options[:primary_presenter].configuration[:query_strategy]
          else
            :legacy
          end

  return Brainstem::QueryStrategies::MyAwesomeFilterStrat.new(options) if strat == :my_awesome_filter_strat
  return Brainstem::QueryStrategies::FilterOrSearch.new(options)
end
```

This can then be enabled in a presenter with:

```ruby
query_strategy :my_awesome_filter_strat`.
```
