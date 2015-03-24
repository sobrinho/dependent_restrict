module ActiveRecord
  # This error is raised when trying to destroy a parent instance in N:1 or 1:1 associations
  # (has_many, has_one) when there is at least 1 child associated instance.
  # ex: if @project.tasks.size > 0, DeleteRestrictionError will be raised when trying to destroy @project
  class DetailedDeleteRestrictionError < ActiveRecordError #:nodoc:
    def initialize(model, klass, record_or_collection)
      @model = model
      @klass = klass
      @record_or_collection = record_or_collection

      super(basic_message)
    end

    def basic_message
      count = @record_or_collection.respond_to?(:count) ? @record_or_collection.count : (@record_or_collection ? 1 : 0)
      name = @klass.human_name(:count => count)
      default = count == 1 ? "Cannot delete record because dependent #{name} exists" : "Cannot delete record because #{count} dependent #{name.pluralize} exist"

      I18n.t('dependent_restrict.basic_message', :count => count, :name => name, :default => default)
    end

    def detailed_message
      count = @record_or_collection.count
      examples = @record_or_collection.all(:limit => 5).map{|o| "#{o.id}: #{o.to_s}"}
      examples[4] = "...#{I18n.t('dependent_restrict.detailed_message.and_more', :count => count - 4, :default => "and #{count-4} more")}" if count > 5

      basic_message + "\n\n\n#{I18n.t('dependent_restrict.detailed_message.includes', :default => "These include")}:\n#{examples.join("\n")}"
    end
  end
end
