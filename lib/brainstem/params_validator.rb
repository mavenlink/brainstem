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
        param = @valid_params_config[param_key]

        if param.blank?
          @unknown_params << param_key
          next
        end

        param_config = param[:_config]
        if param_config[:only].present? && !param_config[:only].map(&:to_s).include?(@action_name)
          @unknown_params << param_key

        elsif param_config[:recursive].to_s == 'true'
          next if param_value.blank?

          @sanitized_params[param_key] = validate_recursive_params!(param_config[:type], param_key, param_value)
        else
          @sanitized_params[param_key] = param_value
        end
      end

      raise_with_unknown_params? ? unknown_params_error! : @sanitized_params
    end

    private

    def validate_recursive_params!(param_type, param_key, param_value)
      if param_type == 'hash'
        validate_recursive_param(param_key, param_value)
      else
        param_value.each_with_index.map { |value, index| validate_recursive_param(param_key, value, index) }
      end
    end

    def validate_recursive_param(param_key, param_value, index = nil)
      begin
        result = self.class.validate!(@action_name, param_value, @valid_params_config, @options)
      rescue Brainstem::UnknownParams => e
        @unknown_params << { param_key => e.unknown_params }
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
