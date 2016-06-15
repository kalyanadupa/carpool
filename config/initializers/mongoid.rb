# frozen_string_literal: true

# Include GlobalID into Mongoid documents to pass references to Active Job tasks
Mongoid::Document.send(:include, GlobalID::Identification)
Mongoid::Relations::Proxy.send(:include, GlobalID::Identification)

# This patch is needed because within_spherical_circle was removed in Mongoid 4.
#
# Ref: https://jira.mongodb.org/browse/MONGOID-3767
#
# TODO: Get rid of this

module Origin
  module Selectable
    def within_spherical_circle(criterion = nil)
      __expanded__(criterion, '$geoWithin', '$centerSphere')
    end
    key :within_spherical_circle, :expanded, '$geoWithin', '$centerSphere'
  end
end

# This class is needed because Mongoid 4 doesn't support Multi-parameter
# attributes.
#
# Ref: https://jira.mongodb.org/browse/MONGOID-2954
#
# TODO: Get rid of this

# rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
module Mongoid
  # Adds Rails' multi-parameter attribute support to Mongoid.
  #
  # @todo: Durran: This module needs an overhaul.
  module MultiParameterAttributes
    module Errors
      # Raised when an error occurred while doing a mass assignment to an
      # attribute through the <tt>attributes=</tt> method. The exception
      # has an +attribute+ property that is the name of the offending attribute.
      class AttributeAssignmentError < Mongoid::Errors::MongoidError
        attr_reader :exception, :attribute

        def initialize(message, exception, attribute)
          @exception = exception
          @attribute = attribute
          @message = message
        end
      end

      # Raised when there are multiple errors while doing a mass assignment
      # through the +attributes+ method. The exception has an +errors+
      # property that contains an array of AttributeAssignmentError
      # objects, each corresponding to the error while assigning to an
      # attribute.
      class MultiparameterAssignmentErrors < Mongoid::Errors::MongoidError
        attr_reader :errors

        def initialize(errors)
          @errors = errors
        end
      end
    end

    # Process the provided attributes casting them to their proper values if a
    # field exists for them on the document. This will be limited to only the
    # attributes provided in the suppied +Hash+ so that no extra nil values get
    # put into the document's attributes.
    #
    # @example Process the attributes.
    #   person.process_attributes(:title => "sir", :age => 40)
    #
    # @param [ Hash ] attrs The attributes to set.
    #
    # @since 2.0.0.rc.7
    def process_attributes(attrs = nil)
      if attrs
        errors = []
        attributes = attrs.class.new
        attributes.permit! if attrs.respond_to?(:permitted?) && attrs.permitted?
        multi_parameter_attributes = {}

        attrs.each_pair do |key, value|
          if key =~ /\A([^\(]+)\((\d+)([if])\)$/
            key = Regexp.last_match(1)
            index = Regexp.last_match(2).to_i
            (multi_parameter_attributes[key] ||= {})[index] = value.empty? ? nil : value.send("to_#{Regexp.last_match(3)}")
          else
            attributes[key] = value
          end
        end

        multi_parameter_attributes.each_pair do |key, values|
          begin
            values = (values.keys.min..values.keys.max).map { |i| values[i] }
            field = self.class.fields[database_field_name(key)]
            attributes[key] = instantiate_object(field, values)
          rescue => e
            errors << Errors::AttributeAssignmentError.new(
              "error on assignment #{values.inspect} to #{key}", e, key
            )
          end
        end

        unless errors.empty?
          raise Errors::MultiparameterAssignmentErrors.new(errors),
                "#{errors.size} error(s) on assignment of multiparameter attributes"
        end
        super(attributes)
      else
        super
      end
    end

    protected

    def instantiate_object(field, values_with_empty_parameters)
      return nil if values_with_empty_parameters.all?(&:nil?)
      values = values_with_empty_parameters.collect { |v| v.nil? ? 1 : v }
      klass = field.type
      if klass == DateTime || klass == Date || klass == Time
        field.mongoize(values)
      elsif klass
        klass.new(*values)
      else
        values
      end
    end
  end
end
# rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
