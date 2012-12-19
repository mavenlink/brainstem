require 'api_presenter/association_field'

module ApiPresenter
  class PresenterCollection
    attr_accessor :default_max_per_page, :default_per_page

    def initialize
      @default_per_page = 20
      @default_max_per_page = 200
    end

    def presenting(name, options = {}, &block)
      options[:params] ||= {}
      presented_class = (options[:model] || name).to_s.classify.constantize
      scope = presented_class.instance_eval(&block)

      # grab the presenter that knows about filters and sorting etc.
      options[:presenter] = for!(presented_class)

      # table name will be used to query the database for the filtered data
      options[:table_name] = presented_class.table_name

      # key these models will use in the struct that is output
      options[:as] ||= name.to_s.tableize.to_sym

      # the other methods need this to be a symbol. I think.
      name = name.to_s.to_sym

      # Filter
      scope = run_filters scope, options

      if options[:params][:only].present?
        # Handle Only
        scope, count = handle_only(scope, options[:params][:only])
      else
        # Paginate
        scope, count = paginate scope, options.merge(:name => name)
      end

      # Ordering
      scope = handle_ordering scope, options

      # Load Includes
      records = scope.to_a
      model = records.first
      allowed_includes = {}

      # Gather allowed includes from the presented hash
      model ||= presented_class.new
      options[:presenter].present(model).each do |k, v|
        next unless v.is_a?(AssociationField)

        if v.json_name
          v.json_name = v.json_name.tableize
        else
          association = model.class.reflections[v.method_name]
          if !association.options[:polymorphic]
            v.json_name = association && association.table_name
            if v.json_name.nil?
              raise ":json_name is a required option for method-based associations (#{presented_class}##{v.method_name})"
            end
          end
        end
        allowed_includes[k.to_sym] = v
      end

      includes_hash = filter_includes options[:params][:include], allowed_includes
      models = perform_preloading records, includes_hash
      primary_models, associated_models = gather_associations(models, name, includes_hash)
      struct = { :count => count, options[:as] => [] }

      associated_models.each do |json_name, models|
        models.flatten!
        models.uniq!

        if models.length > 0
          presenter = for!(models.first.class)
          assoc = includes_hash.to_a.find { |k, v| v[:json_name] == json_name }
          associated_fields = (assoc && assoc.last[:fields]) || []
          struct[json_name] = presenter.group_present(models, associated_fields, [])
        else
          struct[json_name] = []
        end
      end

      if primary_models.length > 0
        primary_object_fields = (options[:params][:fields] || "").split(",").map(&:to_sym)
        struct[options[:as]] += options[:presenter].group_present(models, primary_object_fields, includes_hash.keys)
      end

      struct
    end

    def paginate(scope, options)
      max_per_page = (options[:max_per_page] || default_max_per_page).to_i
      per_page = (options[:params][:per_page] || options[:per_page] || default_per_page).to_i
      per_page = max_per_page if per_page > max_per_page
      per_page = (options[:per_page] || default_per_page).to_i if per_page < 1

      page = (options[:params][:page] || 1).to_i
      page = 1 if page < 1

      [scope.limit(per_page).offset(per_page * (page - 1)).uniq, scope.select("distinct `#{options[:table_name]}`.id").count] # as of Rails 3.2.5, uniq.count generates the wrong SQL.
    end

    def filter_includes(user_includes, allowed_includes)
      includes = {}
      (user_includes || "").split(';').each do |include|
        include_type, fields = include.split(":")
        includes[include_type.to_sym] = (fields || "").split(",").map(&:to_sym)
      end

      filtered_includes = {}
      includes.each do |k, fields|
        allowed = allowed_includes[k] || allowed_includes[k.to_s]
        if allowed
          filtered_includes[k] = {
            :fields => fields,
            :association => allowed.method_name.to_sym,
            :json_name => allowed.json_name.try(:to_sym)
          }
        end
      end
      filtered_includes
    end

    def handle_only(scope, only)
      ids = (only || "").split(",").select {|id| id =~ /\A\d+\Z/}.uniq
      [scope.where(:id => ids), scope.where(:id => ids).count]
    end

    def run_filters(scope, options)
      allowed_filters = options[:presenter].filters || {}
      requested_filters = {}
      (options[:params][:filters] || "").split(",").each do |filter_string|
        name, value = filter_string.split(":")
        value = value == "true" ? true : (value == "false" ? false : value)
        requested_filters[name.to_sym] = value
      end

      allowed_filters.each do |filter_name, filter|
        options, filter_lambda = filter
        args = requested_filters[filter_name] || options[:default]
        next if args.nil?

        if filter_lambda
          scope = filter_lambda.call(scope, *args)
        else
          scope = scope.send(filter_name, *args)
        end
      end

      scope
    end

    def handle_ordering(scope, options)
      default_column, default_direction = (options[:presenter].default_sort_order || "updated_at:desc").split(":")
      sort_name, direction = (options[:params][:order] || "").split(":")
      options[:sort_orders] = (options[:presenter].sort_orders || {})

      if sort_name.present? && options[:sort_orders][sort_name.to_sym]
        order = options[:sort_orders][sort_name.to_sym]
      else
        order = options[:sort_orders][default_column.to_sym]
        direction = default_direction
      end

      case order
      when Proc
        order.call(scope, direction == "desc" ? "desc" : "asc")
      when nil
        scope
      else
        scope.order(order.to_s + " " + (direction == "desc" ? "desc" : "asc"))
      end
    end

    def perform_preloading(records, includes_hash)
      records.tap do |models|
        association_names_to_preload = includes_hash.values.map {|i| i[:association] }
        if models.first
          reflections = models.first.reflections
          association_names_to_preload.reject! { |association| !reflections.has_key?(association) }
        end
        if association_names_to_preload.any?
          ActiveRecord::Associations::Preloader.new(models, association_names_to_preload).run
          ApiPresenter.logger.info "Eager loaded #{association_names_to_preload.join(", ")}."
        end
      end
    end

    def gather_associations(models, name, includes_hash)
      name = name.to_sym
      record_hash = { name => [] }
      primary_models = []

      includes_hash.each do |include, include_data|
        record_hash[include_data[:json_name]] ||= [] if include_data[:json_name]
      end

      models.each do |model|
        primary_models << model

        includes_hash.each do |include, include_data|
          models = Array(model.send(include_data[:association]))
          if include_data[:json_name]
            record_hash[include_data[:json_name]] += models
          else
            # polymorphic associations' tables must be figured out now
            models.each do |record|
              json_name = record.class.table_name.to_sym
              record_hash[json_name] ||= []
              record_hash[json_name] << record
            end
          end
        end
      end

      [primary_models, record_hash]
    end

    # @!visibility private
    class ApiFilterLambda < Proc; end

    def presenters
      @presenters ||= {}
    end

    def add_presenter_class(presenter_class, *klasses)
      klasses.each do |klass|
        presenters[klass.to_s] = presenter_class.new
      end
    end

    def for(klass)
      presenters[klass.to_s]
    end

    def for!(klass)
      self.for(klass) || raise(ArgumentError, "Unable to find a presenter for class #{klass}")
    end
  end
end
