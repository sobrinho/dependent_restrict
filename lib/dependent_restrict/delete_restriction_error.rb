module ActiveRecord
  # This error is raised when trying to destroy a parent instance in N:1 or 1:1 associations
  # (has_many, has_one) when there is at least 1 child associated instance.
  # ex: if @project.tasks.size > 0, DeleteRestrictionError will be raised when trying to destroy @project
  class DetailedDeleteRestrictionError < ActiveRecordError #:nodoc:
    def initialize(name, record)
      @name = name
      @record = record
      super(basic_message)
    end

    def basic_message
      assoc = @record.send(@name)
      count = assoc.respond_to?(:count) ? assoc.count : (assoc ? 1 : 0)
      name = I18n.t(@name.to_s.singularize, {
        :scope => [:activerecord, :models],
        :count => count,
        :default => count == 1 ? @name.to_s.gsub('_', ' ') : @name.to_s.gsub('_', ' ').pluralize
      }).downcase

      if count == 1
        I18n.t('dependent_restrict.basic_message.one', :name => name, :default => "Cannot delete record because dependent #{name} exists")
      else
        I18n.t('dependent_restrict.basic_message.others', :count => count, :name => name, :default => "Cannot delete record because #{count} dependent #{name.pluralize} exist")
      end
    end

    def detailed_message
      count = @record.send(@name).count
      examples = @record.send(@name).all(:limit => 5).map{|o| "#{o.id}: #{o.to_s}"}
      examples[4] = "...#{I18n.t('dependent_restrict.detailed_message.and_more', :count => count - 4, :default => "and #{count-4} more")}" if count > 5

      basic_message + "\n\n\n#{I18n.t('dependent_restrict.detailed_message.includes', :default => "These include")}:\n#{examples.join("\n")}"
    end
  end
end
