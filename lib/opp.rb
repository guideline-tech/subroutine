require "opp/version"
require 'active_support/core_ext/hash/indifferent_access'
require 'active_model'

module Opp

  class Failure < StandardError
    attr_reader :record
    def initialize(record)
      @record = record
      errors = @record.errors.full_messages.join(", ")
      super(errors)
    end
  end

  class Base

    include ::ActiveModel::Model
    include ::ActiveModel::Validations::Callbacks

    class << self

      # fields can be provided in the following way:
      # field :field1, :field2
      # field :field3, :field4, default: 'my default'
      # field field5: 'field5 default', field6: 'field6 default'
      def field(*fields)
        last_hash = fields.extract_options!
        options   = last_hash.slice(:default, :scope)

        fields << last_hash.except(:default, :scope)

        fields.each do |f|

          if f.is_a?(Hash)
            f.each do |k,v|
              field(k, options.merge(:default => v))
            end
          else

            _field(f, options)
          end
        end

      end
      alias_method :fields, :field


      def inputs_from(*ops)
        ops.each do |op|
          field(*op._fields)
          defaults(op._defaults)
          error_map(op._error_map)
        end
      end


      def default(pairs)
        self._defaults.merge!(pairs.stringify_keys)
      end
      alias_method :defaults, :default


      def error_map(map)
        self._error_map.merge!(map)
      end
      alias_method :error_maps, :error_map


      def inherited(child)
        super

        child._fields     = []
        child._defaults   = {}
        child._error_map  = {}

        child._fields      |= self._fields
        child._defaults.merge!(self._defaults)
        child._error_map.merge!(self._error_map)
      end


      def submit!(*args)
        op = new(*args)
        op.submit!

        op
      end

      def submit(*args)
        op = new(*args)
        op.submit
        op
      end

      protected

      def _field(field_name, options = {})
        field = [options[:scope], field_name].compact.join('_')
        self._fields += [field]

        attr_accessor field

        default(field => options[:default]) if options[:default]
      end

    end


    class_attribute :_fields
    self._fields = []
    class_attribute :_defaults
    self._defaults = {}
    class_attribute :_error_map
    self._error_map = {}

    attr_reader :original_params
    attr_reader :params


    def initialize(inputs = {})
      @original_params  = inputs.with_indifferent_access
      @params           = {}

      self.class._defaults.each do |k,v|
        self.send("#{k}=", v.respond_to?(:call) ? v.call : v)
      end
    end


    def submit!
      unless submit
        raise ::Opp::Failure.new(self)
      end
      true
    end

    # the action which should be invoked upon form submission (from the controller)
    def submit
      debug_submission do
        @params = filter_params(@original_params)

        set_accessors(@params)

        validate_and_perform
      end

    rescue Exception => e
      if e.respond_to?(:record)
        inherit_errors_from(e.record) unless e.record == self
        false
      else
        raise e
      end
    end

    protected

    def debug_submission
      yield
    end


    def validate_and_perform
      return false unless valid?
      perform
    end

    # implement this in your concrete class.
    def perform
      raise NotImplementedError
    end

    def field_provided?(key)
      @params.has_key?(key)
    end


    # applies the errors to the form object from the child object, optionally at the namespace provided
    def inherit_errors_from(object, namespace = nil)
      inherit_errors(object.errors, namespace)
    end


    # applies the errors in error_object to self, optionally at the namespace provided
    # returns false so failure cases can end with this invocation
    def inherit_errors(error_object, namespace = nil)
      error_object.each do |k,v|

        keys  = [k, [namespace, k].compact.join('_')].map(&:to_sym).uniq
        keys  = keys.map{|key| _error_map[key] || key }

        match = keys.detect{|key| self.respond_to?(key) || @original_params.try(:has_key?, key) }

        if match
          errors.add(match, v)
        else
          errors.add(:base, error_object.full_message(k, v))
        end

      end

      false
    end


    # if you want to use strong parameters or something in your form object you can do so here.
    def filter_params(inputs)
      inputs.slice(*_fields)
    end


    def set_accessors(inputs, namespace = nil)
      inputs.each do |key, value|

        setter = [namespace, key].compact.join('_')

        if respond_to?("#{setter}=") && _fields.include?(setter)
          send("#{setter}=", value)
        elsif value.is_a?(Hash)
          set_accessors(value, setter)
        end
      end
    end

  end

end
