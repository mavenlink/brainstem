require 'brainstem/concerns/inheritable_configuration'
require 'active_support/core_ext/object/with_options'

module Brainstem
  module Concerns
    module ControllerDSL
      extend ActiveSupport::Concern
      include Brainstem::Concerns::InheritableConfiguration

      DEFAULT_BRAINSTEM_PARAMS_CONTEXT = :_default
      DYNAMIC_KEY = :_dynamic_key

      included do
        reset_configuration!
      end

      module ClassMethods
        def reset_configuration!
          configuration.nest! :_default
          configuration[:_default].tap do |default|
            default.nest! :valid_params
            default.nest! :transforms
            default.nonheritable! :title
            default.nonheritable! :description
            default.nonheritable! :tag
            default.nonheritable! :tag_groups
          end
        end

        #
        # In order to correctly scope the DSL, we must have a context under
        # which keys are stored. The default context is _default (to avoid
        # any potential collisions with methods named 'default'), and this
        # context is used as the parent context for all other contexts.
        #
        # The context will change, for example, when we are adding keys to the
        # configuration for actions. In those cases, the context becomes the
        # +action_name+.
        #
        # Any methods that change the context should change it back upon
        # conclusion so that the assumption of consistent scope inside a block
        # is possible.
        #
        attr_accessor :brainstem_params_context

        #
        # Container method that sets up base scoping for the configuration.
        #
        def brainstem_params(&block)
          self.brainstem_params_context = DEFAULT_BRAINSTEM_PARAMS_CONTEXT
          class_eval(&block)
          self.brainstem_params_context = nil
        end

        #
        # Temporary implementation to track controllers that have been documented.
        #
        def documented!
          configuration[brainstem_params_context][:documented] = true
        end

        #
        # Specifies that the scope should not be documented. Setting this on
        # the default context will force the controller to be undocumented,
        # whereas setting it within an action context will force that action to
        # be undocumented.
        #
        def nodoc!(description = true)
          configuration[brainstem_params_context][:nodoc] = description
        end

        #
        # Specifies that the scope should not be documented unless the `--include-internal`
        # flag is passed in the CLI. Setting this on the default context
        # will force the controller to be undocumented, whereas setting it
        # within an action context will force that action to be undocumented.
        #
        def internal!(description = true)
          configuration[brainstem_params_context][:internal] = description
        end

        #
        # Specifies which presenter is used for the controller / action.
        # By default, expects presentation on all methods, and falls back to the
        # class derived from +brainstem_model_name+ if a name is not
        # given.
        #
        # Setting the +:nodoc+ option marks this presenter as 'internal use only',
        # and causes formatters to display this as not indicated.
        #
        # Setting the +:internal+ option marks this presenter as 'internal use only',
        # and causes formatters to not display this unless documentation is generated with
        # `--include-internal` flag.
        #
        # @param [Class] target_class the target class of the presenter (i.e the model it presents)
        # @param [Hash] options options to record with the presenter
        # @option options [Boolean] :nodoc whether this presenter should not be output in the documentation.
        #
        def presents(target_class = :default, options = { nodoc: false, internal: false })
          raise "`presents` must be a class (in #{self.to_s})" \
            unless target_class.is_a?(Class) || target_class == :default || target_class.nil?

          target_class = brainstem_model_class if target_class == :default
          configuration[brainstem_params_context][:presents] = options.merge(target_class: target_class)
        end

        #
        # Specifies a title to be used in the description of a class. Can also
        # be used for method section titles.
        #
        # Setting the +:nodoc+ option marks this title as 'internal use only',
        # and causes formatters to fall back to the controller constant or to
        # the action name as appropriate. If you are trying to set the entire
        # controller or action as nondocumentable, instead, use the
        # +.nodoc!+ method in the desired context without a block.
        #
        # Setting the +:internal+ option marks this title as 'internal use only',
        # and causes formatters to fall back to the controller constant or to
        # the action name as appropriate unless documentation is generated with
        # `--include-internal` flag. If you are trying to set the entire
        # controller or action as nondocumentable unless internal, instead,
        # use the +.internal!+ method in the desired context without a block.
        #
        # @param [String] text The title to set
        # @param [Hash] options options to record with the title
        # @option options [Boolean] :nodoc whether this title should not be output in the documentation.
        #
        def title(text, options = { nodoc: false, internal: false })
          configuration[brainstem_params_context][:title] = options.merge(info: text)
        end

        #
        # Specifies a low-level description of a particular context, usually
        # (but not exclusively) reserved for methods.
        #
        # Setting the +:nodoc+ option marks this description as 'internal use
        # only', and causes formatters not to display a description.
        #
        # Setting the +:internal+ option marks this description as 'internal use
        # only', and causes formatters not to display a description unless documentation
        # is generated with `--include-internal` flag.
        #
        # @param [String] text The description to set
        # @param [Hash] options options to record with the description
        # @option options [Boolean] :nodoc whether this description should not be output in the documentation.
        #
        def description(text, options = { nodoc: false, internal: false })
          configuration[brainstem_params_context][:description] = options.merge(info: text)
        end

        ####################################################
        # Used only for Open API Specification generation. #
        ####################################################
        #
        # Specifies the tag name to be used in tagging a class.
        #
        # @param [String] tag_name The name of the tag.
        #
        def tag(tag_name)
          unless brainstem_params_context == DEFAULT_BRAINSTEM_PARAMS_CONTEXT
            raise "`tag` is not endpoint specific and is defined on the controller"
          end

          configuration[brainstem_params_context][:tag] = tag_name
        end

        ####################################################
        # Used only for Open API Specification generation. #
        ####################################################
        #
        # Specifies an array of tag names to group the class under. Used for the x-tags OAS vendor extension.
        #
        # @param [Array<String>] tag_group_names Array of tag group names
        #
        def tag_groups(*tag_group_names)
          unless brainstem_params_context == DEFAULT_BRAINSTEM_PARAMS_CONTEXT
            raise "`tag_groups` is not endpoint specific and is defined on the controller"
          end

          configuration[brainstem_params_context][:tag_groups] = tag_group_names.flatten
        end

        #
        # Invokes +action+ for each symbol in the argument list. Used to
        # specify shared configuration.
        #
        def actions(*axns, &block)
          axns.flatten.each { |name| action_context name, &block }
        end

        #
        # Allows the bulk specification of +:root+ options. Useful for
        # denoting parameters which are nested under a resource.
        #
        # +root+ may be specified as a string or symbol, which will represent
        # the final root key.
        #
        # However, +root+ can also be specified as a Proc / callable object, in
        # which case it is evaluated at format time, passed the controller
        # constant. By default, if no argument is passed, it will return the
        # controller's +brainstem_model_name+ dynamically. 
        #
        # We provide this functionality as a way to handle parameter inheritance
        # in subclasses where the brainstem_model_name may not be the same as
        # the parent class.
        #
        # @params root [Symbol,String,Proc] the brainstem model name or a
        #   method accepting the controller constant and returning one
        #
        def model_params(root = Proc.new { |klass| klass.brainstem_model_name }, &block)
          with_options(format_root_ancestry_options(root), &block)
        end

        #
        # Adds a param to the list of valid params, storing
        # the info sent with it.
        #
        # @param [Symbol] name the name of the param
        # @param [String, Symbol] type the data type of the field. If not specified, will default to `string`.
        # @param [Hash] options
        # @option options [String] :info the documentation for the param
        # @option options [String, Symbol] :root if this is a nested param,
        #   under which param should it be nested?
        # @option options [Boolean] :nodoc should this param appear in the
        #   documentation?
        # @option options [Boolean] :required if the param is required for
        #   the endpoint
        # @option options [String, Symbol] :item_type The data type of the items contained in a field.
        #   Only used when the data type of the field is an `array`.
        # @option options [Proc, Symbol] :if Proc to execute or method to run in the instance context of the controller.
        #    Param is included in `brainstem_valid_params` if method is truthy, otherwise excludes the param.
        #
        def valid(name, type = nil, options = {}, &block)
          valid_params = configuration[brainstem_params_context][:valid_params]
          param_config = format_field_configuration(valid_params, name, type, options, &block)

          formatted_name = convert_to_proc(name)
          valid_params[formatted_name] = param_config

          with_options(format_ancestry_options(formatted_name, param_config), &block) if block_given?
        end

        #
        # Adds a param that has a dynamic key to the list of valid params, storing
        # the info sent with it.
        #
        # @param [String, Symbol] type the data type of the field. If not specified, will default to `string`.
        # @param [Hash] options
        # @option options [String] :info the documentation for the param
        # @option options [String, Symbol] :root if this is a nested param,
        #   under which param should it be nested?
        # @option options [Boolean] :nodoc should this param appear in the
        #   documentation?
        # @option options [Boolean] :required if the param is required for
        #   the endpoint
        # @option options [String, Symbol] :item_type The data type of the items contained in a field.
        #   Only used when the data type of the field is an `array`.
        #
        def valid_dynamic_param(type, options = {}, &block)
          valid(DYNAMIC_KEY, type, options, &block)
        end

        #
        # Allows defining a custom response structure for an action.
        #
        # @param [Symbol] type the data type of the response.
        # @param [Hash] options
        # @option options [String] :info the documentation for the param
        # @option options [Boolean] :nodoc should this block appear in the documentation?
        # @option options [String, Symbol] :item_type The data type of the items contained in a field.
        #   Only used when the data type of the response is an `array`.
        #
        def response(type, options = {}, &block)
          configuration[brainstem_params_context].nest! :custom_response
          custom_response = configuration[brainstem_params_context][:custom_response]

          custom_response[:_config] = format_field_configuration(
            custom_response,
            nil,
            type,
            options,
            &block
          )
          class_eval(&block) if block_given?
        end

        #
        # Allows defining a field block for a custom response
        #
        # @param [Symbol] name the name of the field block of the response.
        # @param [Symbol] type the data type of the response.
        # @param [Hash] options
        # @option options [String] :info the documentation for the param
        # @option options [String, Symbol] :item_type The data type of the items contained in a field.
        #   Only used when the data type of the response is an `array`.
        #
        def fields(name, type, options = {}, &block)
          custom_response = configuration[brainstem_params_context][:custom_response]
          raise "`fields` must be nested under a response block" if custom_response.nil?

          formatted_name = convert_to_proc(name)
          field_block_config = format_field_configuration(custom_response, name, type, options, &block)

          custom_response[formatted_name] = field_block_config
          with_options(format_ancestry_options(formatted_name, field_block_config), &block)
        end

        #
        # Allows defining a field block with a dynamic key for a custom response
        #
        # @param [Symbol] type the data type of the response.
        # @param [Hash] options
        # @option options [String] :info the documentation for the param
        # @option options [String, Symbol] :item_type The data type of the items contained in a field.
        #   Only used when the data type of the response is an `array`.
        #
        def dynamic_key_fields(type, options = {}, &block)
          fields(DYNAMIC_KEY, type, options, &block)
        end

        #
        # Allows defining a field either under a field block or the custom response block.
        #
        # @param [Symbol] name the name of the field of the response.
        # @param [Symbol] type the data type of the response.
        # @param [Hash] options
        # @option options [String] :info the documentation for the param
        # @option options [String, Symbol] :item_type The data type of the items contained in a field.
        #   Only used when the data type of the response is an `array`.
        #
        def field(name, type, options = {})
          custom_response = configuration[brainstem_params_context][:custom_response]
          raise "`fields` must be nested under a response block" if custom_response.nil?

          formatted_name = convert_to_proc(name)
          custom_response[formatted_name] = format_field_configuration(custom_response, name, type, options)
        end

        #
        # Allows defining a field with a dynamic key either under a field block or the custom response block.
        #
        # @param [Symbol] type the data type of the response.
        # @param [Hash] options
        # @option options [String] :info the documentation for the param
        # @option options [String, Symbol] :item_type The data type of the items contained in a field.
        #   Only used when the data type of the response is an `array`.
        #
        def dynamic_key_field(type, options = {})
          field(DYNAMIC_KEY, type, options)
        end

        ####################################################
        # Used only for Open API Specification generation. #
        ####################################################
        #
        # Unique string used to identify the operation. The id MUST be unique among all operations
        # described in the API. Tools and libraries MAY use the operation_id to uniquely identify an
        # operation, therefore, it is recommended to follow common programming naming conventions.
        #
        # @param [String] unique_id
        #
        def operation_id(unique_id)
          if brainstem_params_context == DEFAULT_BRAINSTEM_PARAMS_CONTEXT
            raise "`operation_id` is endpoint specific and cannot be defined on the controller"
          end

          configuration[brainstem_params_context][:operation_id] = unique_id
        end

        ####################################################
        # Used only for Open API Specification generation. #
        ####################################################
        #
        # A list of MIME types the endpoints can consume. This overrides the default consumes definition
        # on the Info object in the Open API Specification.
        #
        # @param [Array<String>] mime_types Array of mime types
        #
        def consumes(*mime_types)
          configuration[brainstem_params_context][:consumes] = mime_types.flatten
        end

        ####################################################
        # Used only for Open API Specification generation. #
        ####################################################
        #
        # A list of MIME types the endpoints can produce. This overrides the default produces definition
        # on the Info object in the Open API Specification.
        #
        # @param [Array<String>] mime_types Array of mime types
        #
        def produces(*mime_types)
          configuration[brainstem_params_context][:produces] = mime_types.flatten
        end

        ####################################################
        # Used only for Open API Specification generation. #
        ####################################################
        #
        # A declaration of which security schemes are applied for this operation. The list of values
        # describes alternative security schemes that can be used. This definition overrides any declared
        # top-level security. To remove a top-level security declaration, an empty array can be used.
        #
        # @param [Array<Hash>] schemes Array of security schemes applicable to the endpoint
        #
        def security(*schemes)
          configuration[brainstem_params_context][:security] = schemes.flatten
        end

        ####################################################
        # Used only for Open API Specification generation. #
        ####################################################
        #
        # Additional external documentation for this operation.
        # e.g {
        #       "description": "Find more info here",
        #       "url": "https://swagger.io"
        #     }
        #
        # @param [Hash] doc_config Hash with the `description` & `url` properties of the external documentation.
        #
        def external_doc(doc_config)
          configuration[brainstem_params_context][:external_doc] = doc_config
        end

        ####################################################
        # Used only for Open API Specification generation. #
        ####################################################
        #
        # The transfer protocol for the operation. Values MUST be from the list: "http", "https", "ws", "wss".
        # The value overrides the default schemes definition in the Info Object.
        #
        # @param [Hash] schemes Array of schemes applicable to the endpoint
        #
        def schemes(*schemes)
          configuration[brainstem_params_context][:schemes] = schemes.flatten
        end

        ####################################################
        # Used only for Open API Specification generation. #
        ####################################################
        #
        # Declares this operation to be deprecated. Usage of the declared operation should be refrained.
        #
        # @param [Hash] schemes Array of schemes applicable to the endpoint
        #
        def deprecated(deprecated)
          configuration[brainstem_params_context][:deprecated] = deprecated
        end

        #
        # Adds a transform to the list of transforms. Used to rename incoming
        # params to their internal names for usage.
        #
        # @example
        #
        #     brainstem_params do
        #       transform :param_from_frontend => :param_for_backend
        #     end
        #
        # @param [Hash] transformations An old_param => new_param mapping.
        #
        def transform(transformations)
          transformations.each_pair do |k, v|
            transforms = configuration[brainstem_params_context][:transforms]
            transforms[k.to_sym] = v.to_sym
          end
        end
        alias_method :transforms, :transform

        #
        # Changes context to a specific action context. Allows specification
        # of per-action configuration.
        #
        # Instead of using this method, it's advised simply to use +actions+
        # with a single method name. While marked as private, since it is
        # usually used within a +class_eval+ block thanks to
        # +brainstem_params+, this has little effect.
        #
        # Originally, this method was named +action+ for parity with the plural
        # version. However, this conflicts in multiple ways with Rails, so it
        # has been renamed.
        #
        # @private
        #
        # @param [Symbol] name the name of the context
        # @param [Proc] block the proc to be evaluated in the context
        #
        def action_context(name, &block)
          new_context = name.to_sym
          old_context = self.brainstem_params_context
          self.brainstem_params_context = new_context

          self.configuration[new_context] ||= Brainstem::DSL::Configuration.new(
            self.configuration[DEFAULT_BRAINSTEM_PARAMS_CONTEXT]
          )

          class_eval(&block)
          self.brainstem_params_context = old_context
        end
        private :action_context

        #
        # Converts the field name into a Proc.
        #
        # @param [String, Symbol, Proc] text The title to set
        # @return [Proc]
        #
        def convert_to_proc(field_name_or_proc)
          field_name_or_proc.respond_to?(:call) ? field_name_or_proc : Proc.new { field_name_or_proc.to_s }
        end
        alias_method :format_root_name, :convert_to_proc

        #
        # Formats the ancestry options of the field. Returns a hash with ancestors & root.
        #
        def format_root_ancestry_options(root_name)
          root_proc = format_root_name(root_name)
          ancestors = [root_proc]

          { root: root_proc, ancestors: ancestors }.with_indifferent_access.reject { |_, v| v.blank? }
        end

        #
        # Formats the ancestry options of the field. Returns a hash with ancestors.
        #
        def format_ancestry_options(field_name_proc, options = {})
          ancestors = options[:ancestors].try(:dup) || []
          ancestors << field_name_proc

          { ancestors: ancestors }.with_indifferent_access.reject { |_, v| v.blank? }
        end

        #
        # Formats the configuration of the param and returns the default configuration if not specified.
        #
        def format_field_configuration(configuration_map, name, type, options = {}, &block)
          field_config = options.with_indifferent_access

          field_config[:type] = type.to_s
          field_config[:dynamic_key] = true if name.present? && name.to_sym == DYNAMIC_KEY

          if options.has_key?(:item_type)
            field_config[:item_type] = field_config[:item_type].to_s
          elsif field_config[:type] == 'array'
            field_config[:item_type] = block_given? ? 'hash' : 'string'
          end

          # Inherit `nodoc` attribute from parent
          parent_key = (field_config[:ancestors] || []).reverse.first
          if parent_key && (parent_field_config = configuration_map[parent_key])
            field_config[:nodoc] ||= !!parent_field_config[:nodoc]
          end

          field_config.delete(:nested_levels) if field_config[:nested_levels].to_i < 2

          DEFAULT_FIELD_CONFIG.merge(field_config).with_indifferent_access
        end

        DEFAULT_FIELD_CONFIG = { nodoc: false, required: false }
        private_constant :DEFAULT_FIELD_CONFIG
      end

      def valid_params_tree(requested_context = action_name.to_sym)
        contextual_key(requested_context, :valid_params)
          .to_h
          .inject(ActiveSupport::HashWithIndifferentAccess.new) do |hsh, (field_name_proc, field_config)|

          if (condition = field_config[:if])
            case condition
            when Symbol
              next hsh unless self.send condition
            when Proc
              next hsh unless instance_exec(&condition)
            end
          end

          field_name = field_name_proc.call(self.class)
          if field_config.has_key?(:ancestors)
            ancestors = field_config[:ancestors].map { |ancestor_key| ancestor_key.call(self.class) }
            parent = ancestors.inject(hsh) do |traversed_hash, ancestor_name|
              traversed_hash[ancestor_name] ||= {}
              traversed_hash[ancestor_name]
            end

            parent[field_name] = { :_config => field_config.except(:root, :ancestors) }
          else
            hsh[field_name] = { :_config => field_config }
          end

          hsh
        end
      end

      #
      # Lists all valid parameters for the current action. Falls back to the
      # valid parameters for the default context.
      #
      # @params [Symbol] requested_context the context which to look up.
      #
      # @return [Hash{String => String, Hash] a hash of pairs of param names and
      # descriptions or sub-hashes.
      #
      def brainstem_valid_params(requested_context = action_name.to_sym, root_param_name = brainstem_model_name)
        valid_params_tree(requested_context)[root_param_name.to_s]
      end
      alias_method :brainstem_valid_params_for, :brainstem_valid_params

      #
      # Lists all incoming param keys that will be rewritten to use a different
      # name for internal usage for the current action.
      #
      # Rewrites all params to be symbols for backwards compatibility.
      #
      # @params [Symbol] requested_context the context which to look up.
      #
      # @return [Hash{Symbol => Symbol}] a map of incoming => internal
      #   param names.
      #
      def transforms(requested_context = action_name.to_sym)
        tforms = contextual_key(requested_context, :transforms).to_h
        tforms.inject({}) do |memo, (k, v)|
          memo[k.to_sym] = v.to_sym
          memo
        end
      end
      alias_method :transforms_for, :transforms

      #
      # Retrieves a specific key in a given context, or if that doesn't exist,
      # falls back to the parent context.
      #
      # @private
      #
      # @params [Symbol] context the context in which to first look for the key
      # @params [Symbol] key the key name to look for
      #
      def contextual_key(context, key)
        if configuration.has_key?(context.to_sym)
          configuration[context.to_sym][key.to_sym]
        else
          configuration[DEFAULT_BRAINSTEM_PARAMS_CONTEXT][key.to_sym]
        end
      end
      private :contextual_key
    end
  end
end
