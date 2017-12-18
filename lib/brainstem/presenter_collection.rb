require 'brainstem/search_unavailable_error'
require 'brainstem/presenter_validator'

module Brainstem
  class PresenterCollection

    # @!attribute default_max_per_page
    # @return [Integer] The maximum number of objects that can be requested in a single presented hash.
    attr_accessor :default_max_per_page

    # @!attribute default_per_page
    # @return [Integer] The default number of objects that will be returned in the presented hash.
    attr_accessor :default_per_page

    attr_accessor :default_max_filter_and_search_page

    # @!visibility private
    def initialize
      @default_per_page = 20
      @default_max_per_page = 200
      @default_max_filter_and_search_page = 10_000 # TODO: figure out a better default and make it configurable
    end

    # The main presentation method, converting a model name and an optional scope into a hash structure, ready to be converted into JSON.
    # If searching, Brainstem filtering, only, pagination, and ordering are skipped and should be implemented with your search solution.
    # All request options are passed to the +search block+ for your convenience.
    # @param [Class, String] name Either the ActiveRecord Class itself, or its pluralized table name as a string.
    # @param [Hash] options The options that will be applied as the objects are converted.
    # @option options [Hash] :params The +params+ hash included in a request for the presented object.
    # @option options [ActiveRecord::Base] :model The model that is being presented (if different from +name+).
    # @option options [Integer] :max_per_page The maximum number of items that can be requested by <code>params[:per_page]</code>.
    # @option options [Integer] :per_page The number of items that will be returned if <code>params[:per_page]</code> is not set.
    # @option options [Boolean] :apply_default_filters Determine if Presenter's filter defaults should be applied.  On by default.
    # @option options [Brainstem::Presenter] :primary_presenter The Presenter to use for filters and sorts. If unspecified, the +:model+ or +name+ will be used to find an appropriate Presenter.
    # @yield Must return a scope on the model +name+, which will then be presented.
    # @return [Hash] A hash of arrays of hashes. Top-level hash keys are pluralized model names, with values of arrays containing one hash per object that was found by the given given options.
    def presenting(name, options = {}, &block)
      options[:params] = HashWithIndifferentAccess.new(options[:params] || {})
      check_for_old_options!(options)
      set_default_filters_option!(options)
      presented_class = (options[:model] || name)
      presented_class = presented_class.classify.constantize if presented_class.is_a?(String)
      scope = presented_class.instance_eval(&block)
      count = 0

      # grab the presenter that knows about filters and sorting etc.
      options[:primary_presenter] ||= for!(presented_class)

      # table name will be used to query the database for the filtered data
      options[:table_name] = presented_class.table_name

      options[:default_per_page] = default_per_page
      options[:default_max_per_page] = default_max_per_page
      options[:default_max_filter_and_search_page] = default_max_filter_and_search_page

      primary_models, count = strategy(options, scope).execute(scope)

      # Determine if an exception should be raised on an empty result set.
      if options[:raise_on_empty] && primary_models.empty?
        raise options[:empty_error_class] || ActiveRecord::RecordNotFound
      end

      structure_response(presented_class, primary_models, count, options)
    end

    def structure_response(presented_class, primary_models, count, options)
      # key these models will use in the struct that is output
      brainstem_key = brainstem_key_for!(presented_class)

      # filter the incoming :includes list by those available from this Presenter in the current context
      selected_associations = filter_includes(options)

      optional_fields = filter_optional_fields(options)
      page_size = per_page(options)

      struct = {
        'count' => count,
        'page_number' => page_number(count, options[:params]),
        'page_count' => page_count(count, page_size),
        'page_size' => page_size,
        'results' => [],
        brainstem_key => {},
      }

      # Build top-level keys for all requested associations.
      selected_associations.each do |association|
        struct[brainstem_key_for!(association.target_class)] ||= {} unless association.polymorphic?
      end

      if primary_models.length > 0
        associated_models = {}
        presented_primary_models = options[:primary_presenter].group_present(primary_models,
                                                                             selected_associations.map(&:name),
                                                                             optional_fields: optional_fields,
                                                                             load_associations_into: associated_models)

        struct[brainstem_key] = presented_primary_models.each.with_object({}) { |model, obj| obj[model['id']] = model }
        struct['results'] = presented_primary_models.map { |model| { 'key' => brainstem_key, 'id' => model['id'] } }

        associated_models.each do |association_brainstem_key, associated_models_hash|
          presenter = for!(associated_models_hash.values.first.class)
          struct[association_brainstem_key] ||= {}
          presenter.group_present(associated_models_hash.values).each do |model|
            struct[association_brainstem_key][model['id']] ||= model
          end
        end
      end

      struct
    end

    # @return [Hash] The presenters this collection knows about, keyed on the names of the classes that can be presented.
    def presenters
      @presenters ||= {}
    end

    # @param [String, Class] presenter_class The presenter class that knows how to present all of the classes given in +klasses+.
    # @param [*Class] klasses One or more classes that can be presented by +presenter_class+.
    def add_presenter_class(presenter_class, *klasses)
      klasses.each do |klass|
        presenters[klass.to_s] = presenter_class
      end
    end

    # @return [Brainstem::Presenter, nil] A new instance of the Presenter that knows how to present the class +klass+, or +nil+ if there isn't one.
    def for(klass)
      presenters[klass.to_s].try(:new)
    end

    # @return [Brainstem::Presenter] A new instance of the Presenter that knows how to present the class +klass+.
    # @raise [ArgumentError] if there is no known Presenter for +klass+.
    def for!(klass)
      self.for(klass) || raise(ArgumentError, "Unable to find a presenter for class #{klass}")
    end

    def brainstem_key_for!(klass)
      presenter = presenters[klass.to_s]
      raise(ArgumentError, "Unable to find a presenter for class #{klass}") unless presenter
      presenter.configuration[:brainstem_key] || klass.table_name
    end

    # @raise [StandardError] if any presenter in this collection is invalid.
    def validate!
      errors = []
      presenters.each do |name, klass|
        validator = Brainstem::PresenterValidator.new(klass)
        unless validator.valid?
          errors += validator.errors.full_messages.map { |error| "#{name}: #{error}" }
        end
      end
      raise "PresenterCollection invalid:\n - #{errors.join("\n - ")}" if errors.length > 0
    end

    private

    def strategy(options, scope)
      strat = options[:primary_presenter].get_query_strategy

      return Brainstem::QueryStrategies::FilterAndSearch.new(options) if strat == :filter_and_search && searching?(options)
      return Brainstem::QueryStrategies::FilterOrSearch.new(options)
    end

    def searching?(options)
      options[:params][:search] && options[:primary_presenter].configuration[:search].present?
    end

    def filter_includes(options)
      allowed_associations = options[:primary_presenter].allowed_associations(options[:params][:only].present?)

      [].tap do |selected_associations|
        (options[:params][:include] || '').split(',').each do |k|
          if association = allowed_associations[k]
            selected_associations << association
          end
        end
      end
    end

    def filter_optional_fields(options)
      options[:params][:optional_fields].to_s.split(',').map(&:strip) & options[:primary_presenter].configuration[:fields].keys
    end

    def set_default_filters_option!(options)
      return unless options[:params].has_key?(:apply_default_filters)

      options[:apply_default_filters] = [true, "true", "TRUE", 1, "1"].include? options[:params].delete(:apply_default_filters)
    end

    def check_for_old_options!(options)
      if options[:as].present?
        raise "PresenterCollection#presenting no longer accepts the :as option.  Use the brainstem_key annotation in your presenters instead."
      end
    end

    def page_number(count, params)
      count > 0 ? params.fetch(:page, 1).to_i : 0
    end

    def page_count(count, per_page)
      count > 0 ? (count.to_f / per_page).ceil : 0
    end

    def per_page(options)
      per_page = [(options[:params][:per_page] || options[:per_page] || default_per_page).to_i, (options[:max_per_page] || default_max_per_page).to_i].min
      per_page = default_per_page if per_page < 1
      per_page
    end
  end
end
