# DependentProtect
#
require 'active_record'
require 'dependent_protect/delete_restriction_error'

module DependentProtect
  VERSION = '0.0.6'

  def self.included(base)
    super
    base.extend(ClassMethods)

    base.class_eval do
      class << self
        alias_method_chain :has_one, :protect
        alias_method_chain :has_many, :protect
        alias_method_chain :has_and_belongs_to_many, :protect
      end
    end
  end

  module ClassMethods
    # We should be aliasing configure_dependency_for_has_many but that method
    # is private so we can't. We alias has_many instead trying to be as fair
    # as we can to the original behaviour.
    def has_one_with_protect(association_id, options = {}, &extension) #:nodoc:
      reflection = create_reflection(:has_one, association_id, options, self)
      add_dependency_callback!(reflection, options)
      has_one_without_protect(association_id, options, &extension)
    end

    def has_many_with_protect(association_id, options = {}, &extension) #:nodoc:
      reflection = create_reflection(:has_many, association_id, options, self)
      add_dependency_callback!(reflection, options)
      has_many_without_protect(association_id, options, &extension)
    end

    def has_and_belongs_to_many_with_protect(association_id, options = {}, &extension)
      reflection = create_reflection(:has_and_belongs_to_many, association_id, options, self)
      add_dependency_callback!(reflection, options)
      options.delete(:dependent)
      has_and_belongs_to_many_without_protect(association_id, options, &extension)
    end

    private
    def add_dependency_callback!(reflection, options)
      case reflection.options[:dependent]
      when :rollback
        options.delete(:dependent)
        method_name = "dependent_rollback_for_#{reflection.name}".to_sym
        define_method(method_name) do
          method = reflection.collection? ? :empty? : :nil?
          unless send(reflection.name).send(method)
            raise ActiveRecord::Rollback
          end
        end
        before_destroy method_name
      when :restrict
        options.delete(:dependent)
        method_name = "dependent_restrict_for_#{reflection.name}".to_sym
        define_method(method_name) do
          method = reflection.collection? ? :empty? : :nil?
          unless send(reflection.name).send(method)
            raise ActiveRecord::DetailedDeleteRestrictionError.new(reflection.name, self)
          end
        end
        before_destroy method_name
      end
    end
  end
end

ActiveRecord::Base.send(:include, DependentProtect)
