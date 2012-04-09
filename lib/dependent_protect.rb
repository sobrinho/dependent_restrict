# DependentProtect
#
require 'activerecord'

module DependentProtect
  VERSION = '0.0.2'

  DESTROY_PROTECT_ERROR_MESSAGE = 'Cant destroy because there are dependent_count dependent_type dependent on dependee_type dependee.\n\n\nThese include:\ndependent_examples'

  def self.included(base)
    super
    base.extend(ClassMethods)

    klass = Class.new(ActiveRecord::ActiveRecordError)
    ActiveRecord.const_set('DependencyError', klass)

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
      has_and_belongs_to_many_without_protect(association_id, options, &extension)
    end

    private
    def add_dependency_callback!(reflection, options)
      # This would break if has_many :dependent behaviour changes. One
      # solution is removing both the second when and the else branches but
      # the exception message wouldn't be exact.
      condition = if reflection.collection?
        "record.#{reflection.name}.empty?"
      else
        "record.#{reflection.name}.nil?"
      end

      case reflection.options[:dependent]
      when :rollback
        options.delete(:dependent)
        module_eval "before_destroy, :protect_rollback, :unless => proc{ |record| #{condition} }"
      when :raise
        options.delete(:dependent)
        error = reflection.collection? ? dependency_error(reflection) : "Cannot remove as the associated object is dependent on this."
        module_eval <<-METHOD
def protect_raise_#{reflection.name}
  raise ActiveRecord::DependencyError, "#{error}"
end
METHOD
        module_eval "before_destroy :protect_raise_#{reflection.name}, :unless => proc{ |record| #{condition} }"
      end
    end

    def protect_rollback
      raise ActiveRecord::Rollback
    end

    def dependency_error(reflection)
      # TODO: gotta be a more easier approach!
      count_code = "#{reflection.name}.count"
      first_five_code = reflection.name.to_s+'.first(5).map{|o| "#{o.id}: #{o.to_s}"}'
      DESTROY_PROTECT_ERROR_MESSAGE.
        gsub('dependent_type', reflection.class_name.to_s.underscore.gsub('_', ' ').pluralize).
        gsub('dependent_examples', '#{(' + first_five_code + ' + [("...and #{' + count_code + ' - 5} more" if ' + count_code + ' > 5)]).join("\n")}').
        gsub('dependent_count', '#{' + count_code + '}').
        gsub('dependee_type', '#{self.class.to_s.underscore.gsub(\'_\', \' \')}').
        gsub('dependee', '#{self}')
    end

  end
end


ActiveRecord::Base.send(:include, DependentProtect)
