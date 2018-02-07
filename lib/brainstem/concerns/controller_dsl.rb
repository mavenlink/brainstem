require 'brainstem/concerns/inheritable_configuration'
require 'active_support/core_ext/object/with_options'

module Brainstem
  module Concerns
    module ControllerDSL
      extend ActiveSupport::Concern
      include Brainstem::Concerns::InheritableConfiguration

      DEFAULT_BRAINSTEM_PARAMS_CONTEXT = :_default

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
        # Specifies that the scope should not be documented. Setting this on
        # the default context will force the controller to be undocumented,
        # whereas setting it within an action context will force that action to
        # be undocumented.
        #
        def nodoc!
          configuration[brainstem_params_context][:nodoc] = true
        end


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
          with_options({ root: sanitize_root_option(root) }, &block)
        end


        #
        # Adds a param to the list of valid params, storing
        # the info sent with it.
        #
        # @param [Symbol] field_name the name of the param
        # @param [Hash] options
        # @option options [String] :info the documentation for the param
        # @option options [String,Symbol] :root if this is a nested param,
        #   under which param should it be nested?
        # @option options [Boolean] :nodoc should this param appear in the
        #   documentation?
        # @option options [Boolean] :required if the param is required for
        #   the endpoint
        #
        def valid(field_name, options = {}, &block)
          valid_params = configuration[brainstem_params_context][:valid_params]

          if block_given?
            options[:type] = 'hash' unless options.has_key?(:type)
            valid_params[field_name.to_sym] = DEFAULT_PARAM_OPTIONS.merge(options)

            ancestors = options[:ancestors] || []
            ancestors << field_name.to_s

            ancestry_options = {
              root: sanitize_root_option(options[:root]),
              ancestors: ancestors
            }.reject { |_, v| v.blank? }

            with_options(ancestry_options, &block)
          else
            options[:type] = options[:type].to_s if options.has_key?(:type)
            valid_params[field_name.to_sym] = DEFAULT_PARAM_OPTIONS.merge(options)
          end
        end

        DEFAULT_PARAM_OPTIONS = { nodoc: false, required: false, type: 'string' }
        private_constant :DEFAULT_PARAM_OPTIONS

        def sanitize_root_option(root)
          root.is_a?(Symbol) ? root.to_s : root
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
        # Specifies which presenter is used for the controller / action.
        # By default, expects presentation on all methods, and falls back to the
        # class derived from +brainstem_model_name+ if a name is not
        # given.
        #
        # Setting the +:nodoc+ option marks this presenter as 'internal use only',
        # and causes formatters to display this as not indicated.
        #
        # @param [Class] target_class the target class of the presenter (i.e
        #   the model it presents)
        # @param [Hash] options options to record with the presenter
        # @option [Boolean] options :nodoc whether this presenter should not
        #   be output in the documentation.
        #
        #
        def presents(target_class = :default, options = { nodoc: false })
          raise "`presents` must be a class (in #{self.to_s})" \
            unless target_class.is_a?(Class) || target_class == :default || target_class.nil?

          target_class = brainstem_model_class if target_class == :default
          configuration[brainstem_params_context][:presents] = \
            options.merge(target_class: target_class)
        end


        #
        # Specifies a low-level description of a particular context, usually
        # (but not exclusively) reserved for methods.
        #
        # Setting the +:nodoc+ option marks this description as 'internal use
        # only', and causes formatters not to display a description.
        #
        # @param [String] text The description to set
        # @param [Hash] options options to record with the description
        # @option [Boolean] options :nodoc whether this description should not
        #   be output in the documentation.
        #
        def description(text, options = { nodoc: false })
          configuration[brainstem_params_context][:description] = \
            options.merge(info: text)
        end


        #
        # Specifies a title to be used in the description of a class. Can also
        # be used for method section titles.
        #
        # Setting the +:nodoc+ option marks this title as 'internal use only',
        # and causes formatters to fall back to the controller constant or to
        # the action name as appropriate. If you are trying to set the entire
        # controller or action as nondocumentable, instead, use the discrete
        # +.nodoc!+ method in the desired context without a block.
        #
        # @param [String] text The title to set
        # @param [Hash] options options to record with the title
        # @option [Boolean] options :nodoc whether this title should not be
        #   output in the documentation.
        #
        def title(text, options = { nodoc: false })
          configuration[brainstem_params_context][:title] = \
            options.merge(info: text)
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
        contextual_key(requested_context, :valid_params)
          .to_h
          .select do |k, v|
            root = v[:root].respond_to?(:call) ? v[:root].call(self.class) : v[:root]
            root.to_s == root_param_name.to_s
          end
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
