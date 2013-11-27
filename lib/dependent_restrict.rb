require 'active_record'
require 'dependent_restrict/delete_restriction_error'

module DependentRestrict
  VERSION = '0.1.2'

  def self.included(base)
    super
    base.extend(ClassMethods)

    base.class_eval do
      class << self
        alias_method_chain :has_one, :restrict
        alias_method_chain :has_many, :restrict
        alias_method_chain :has_and_belongs_to_many, :restrict
      end
    end
  end

  module ClassMethods
    # We should be aliasing configure_dependency_for_has_many but that method
    # is private so we can't. We alias has_many instead trying to be as fair
    # as we can to the original behaviour.
    def has_one_with_restrict(*args) #:nodoc:
      reflection = if active_record_4?
        association_id, options, scope, extension = *args
        create_reflection(:has_one, association_id, options || {}, scope || {}, self)
      else
        association_id, options, extension = *args
        create_reflection(:has_one, association_id, options || {}, self)
      end
      add_dependency_callback!(reflection, options || {})
      has_one_without_restrict(*args) #association_id, options, &extension)
    end

    def has_many_with_restrict(association_id, options = {}, &extension) #:nodoc:
      reflection = if active_record_4?
        create_reflection(:has_many, association_id, options, scope ||= {}, self)
      else
        create_reflection(:has_many, association_id, options, self)
      end
      add_dependency_callback!(reflection, options)
      has_many_without_restrict(association_id, options, &extension)
    end

    def has_and_belongs_to_many_with_restrict(association_id, options = {}, &extension)
      reflection = create_reflection(:has_and_belongs_to_many, association_id, options, self)
      add_dependency_callback!(reflection, options)
      options.delete(:dependent)
      has_and_belongs_to_many_without_restrict(association_id, options, &extension)
    end

    private

    def add_dependency_callback!(reflection, options)
      dependent_type = active_record_4? ? options[:dependent] : reflection.options[:dependent]
      method_name = "dependent_#{dependent_type}_for_#{reflection.name}"
      case dependent_type
      when :rollback, :restrict_with_error
        options.delete(:dependent)
        define_method(method_name) do
          method = reflection.collection? ? :empty? : :nil?
          unless send(reflection.name).send(method)
            raise ActiveRecord::Rollback
          end
        end
        before_destroy method_name
      when :restrict, :restrict_with_exception
        options.delete(:dependent)
        define_method(method_name) do
          method = reflection.collection? ? :empty? : :nil?
          unless send(reflection.name).send(method)
            raise ActiveRecord::DetailedDeleteRestrictionError.new(reflection.name, self)
          end
        end
        before_destroy method_name
      end
    end

    def active_record_4?
      ::ActiveRecord::VERSION::MAJOR == 4
    end

  end
end

ActiveRecord::Base.send(:include, DependentRestrict)
