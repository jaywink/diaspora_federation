module DiasporaFederation
  # Provides a simple DSL for specifying {Entity} properties during class
  # definition.
  #
  # @example
  #   property :prop
  #   property :optional, default: false
  #   property :dynamic_default, default: -> { Time.now }
  #   entity :nested, NestedEntity
  #   entity :multiple, [OtherEntity]
  module PropertiesDSL
    # @return [Array<Hash>] hash of declared entity properties
    def class_props
      @class_props ||= []
    end

    # Define a generic (string-type) property
    # @param [Symbol] name property name
    # @param [Hash] opts further options
    # @option opts [Object, #call] :default a default value, making the
    #   property optional
    def property(name, opts={})
      define_property name, String, opts
    end

    # Define a property that should contain another Entity or an array of
    # other Entities
    # @param [Symbol] name property name
    # @param [Entity, Array<Entity>] type Entity subclass or
    #                Array with exactly one Entity subclass constant inside
    # @param [Hash] opts further options
    # @option opts [Object, #call] :default a default value, making the
    #   property optional
    def entity(name, type, opts={})
      raise InvalidType unless type_valid?(type)

      define_property name, type, opts
    end

    # Return array of missing required property names
    # @return [Array<Symbol>] missing required property names
    def missing_props(args)
      class_prop_names - default_props.keys - args.keys
    end

    # Return a new hash of default values, with dynamic values
    # resolved on each call
    # @return [Hash] default values
    def default_values
      default_props.each_with_object({}) { |(name, prop), hash|
        hash[name] = prop.respond_to?(:call) ? prop.call : prop
      }
    end

    # Returns all nested Entities
    # @return [Array<Hash>] nested properties
    def nested_class_props
      @nested_class_props ||= class_props.select {|p| p[:type] != String }
    end

    # Returns all property names
    # @return [Array] property names
    def class_prop_names
      @class_prop_names ||= class_props.map {|p| p[:name] }
    end

    private

    def define_property(name, type, opts={})
      raise InvalidName unless name_valid?(name)

      class_props << {name: name, type: type}
      default_props[name] = opts[:default] if opts.has_key? :default

      instance_eval { attr_reader name }
    end

    # checks if the name is a +Symbol+ or a +String+
    # @param [String, Symbol] name the name to check
    # @return [Boolean]
    def name_valid?(name)
      name.instance_of?(Symbol) || name.instance_of?(String)
    end

    # checks if the type extends {Entity}
    # @param [Class] type the type to check
    # @return [Boolean]
    def type_valid?(type)
      [type].flatten.all? { |type|
        type.respond_to?(:ancestors) && type.ancestors.include?(Entity)
      }
    end

    def default_props
      @default_props ||= {}
    end

    # Raised, if the name is of an unexpected type
    class InvalidName < RuntimeError
    end

    # Raised, if the type is of an unexpected type
    class InvalidType < RuntimeError
    end
  end
end
