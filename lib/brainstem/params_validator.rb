require 'brainstem/unknown_params'
require 'brainstem/malformed_params'
require 'brainstem/validation_error'

module Brainstem
  class ParamsValidator
    attr_reader :malformed_params, :unknown_params

    def self.validate!(action_name, input_params, valid_params_config)
      new(action_name, input_params, valid_params_config).validate!
    end

    def initialize(action_name, input_params, valid_params_config)
      @valid_params_config = valid_params_config
      @input_params        = sanitize_input_params!(input_params)
      @action_name         = action_name.to_s

      @unknown_params      = []
      @malformed_params    = []
    end

    def validate!
      @input_params.each do |param_key, param_value|
        param_data = @valid_params_config[param_key]

        if param_data.blank?
          @unknown_params << param_key
          next
        end

        param_config        = param_data[:_config]
        nested_valid_params = param_data.except(:_config)

        if param_config[:only].present? && !param_config[:only].map(&:to_s).include?(@action_name)
          @unknown_params << param_key
        elsif param_config[:recursive].to_s == 'true'
          validate_nested_params(param_key, param_config, param_value, @valid_params_config)
        elsif parent_param?(param_data)
          validate_nested_params(param_key, param_config, param_value, nested_valid_params)
        end
      end

      raise_when_invalid? ? unknown_params_error! : true
    end

    private

    def raise_when_invalid?
      @malformed_params.present? || @unknown_params.present?
    end

    def parent_param?(param_data)
      param_data.except(:_config).keys.present?
    end

    def validate_nested_params(param_key, param_config, value, valid_nested_params)
      return value if value.nil?

      param_type = param_config[:type]
      if param_type == 'hash'
        validate_nested_param(param_key, param_type, value, valid_nested_params)
      elsif param_type == 'array' && !value.is_a?(Array)
        @malformed_params << param_key
      else
        value.each { |value| validate_nested_param(param_key, param_type, value, valid_nested_params) }
      end
    end

    def validate_nested_param(parent_param_key, parent_param_type, value, valid_nested_params)
      begin
        self.class.validate!(@action_name, value, valid_nested_params)
      rescue Brainstem::ValidationError => e
        @unknown_params << { parent_param_key => e.unknown_params }
        @malformed_params << { parent_param_key => e.malformed_params }
      end
    end

    def sanitize_input_params!(input_params)
      malformed_params_error! unless input_params.is_a?(Hash) && input_params.present?

      input_params
    end

    def malformed_params_error!
      raise ::Brainstem::ValidationError.new("Input params are malformed")
    end

    def unknown_params_error!
      raise ::Brainstem::ValidationError.new("Invalid params encountered", @unknown_params, @malformed_params)
    end
  end
end
