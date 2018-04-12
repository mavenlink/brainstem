require 'brainstem/unknown_params'

module Brainstem
  class ParamsValidator
    attr_reader :unknown_params, :sanitized_params

    def self.validate!(action_name, input_params, valid_params_config, options = {})
      new(action_name, input_params, valid_params_config, options).validate!
    end

    def initialize(action_name, input_params, valid_params_config, options = {})
      @valid_params_config = valid_params_config
      @options             = options
      @input_params        = sanitize_input_params!(input_params)
      @action_name         = action_name.to_s

      @unknown_params      = []
      @sanitized_params    = {}
    end

    def validate!
      @input_params.each do |param_key, param_value|
        param_data = @valid_params_config[param_key]

        if param_data.blank?
          @unknown_params << param_key
          next
        end

        param_config = param_data[:_config]
        if param_config[:only].present? && !param_config[:only].map(&:to_s).include?(@action_name)
          @unknown_params << param_key

        elsif param_config[:recursive].to_s == 'true'
          next if param_value.blank? # Doubts

          @sanitized_params[param_key] = validate_recursive_params!(param_key, param_data, param_value)
        elsif parent_param?(param_data)
          # next if param_value.blank? # Doubts

          @sanitized_params[param_key] = validate_nested_params!(param_key, param_data, param_value)
        else
          @sanitized_params[param_key] = param_value
        end
      end

      raise_with_unknown_params? ? unknown_params_error! : @sanitized_params
    end

    private

    def parent_param?(param_data)
      param_data.except(:_config).keys.present?
    end

    def validate_recursive_params!(parent_param_key, parent_param_config, value)
      if parent_param_config[:_config][:type] == 'hash'
        validate_nested_param(parent_param_key, value, @valid_params_config)
      else
        value.map { |value| validate_nested_param(parent_param_key, value, @valid_params_config) }
      end
    end

    def validate_nested_params!(parent_param_key, parent_param_config, value)
      valid_nested_params = parent_param_config.except(:_config)

      if parent_param_config[:_config][:type] == 'hash'
        validate_nested_param(parent_param_key, value, valid_nested_params)
      else
        value.map { |value| validate_nested_param(parent_param_key, value, valid_nested_params) }
      end
    end

    def validate_nested_param(parent_param_key, value, valid_params)
      begin
        result = self.class.validate!(@action_name, value, valid_params, @options)
      rescue Brainstem::UnknownParams => e
        @unknown_params << { parent_param_key => e.unknown_params }
      end

      result
    end

    def raise_with_unknown_params?
      !ignore_unknown_params? && @unknown_params.present?
    end

    def ignore_unknown_params?
      @options[:ignore_unknown_fields].to_s == 'true'
    end

    def sanitize_input_params!(input_params)
      missing_params_error! unless input_params.is_a?(Hash) && input_params.present?

      input_params
    end

    def missing_params_error!
      raise ::Brainstem::UnknownParams.new("Missing required parameters")
    end

    def unknown_params_error!
      raise ::Brainstem::UnknownParams.new("Unknown params encountered", @unknown_params)
    end
  end
end
