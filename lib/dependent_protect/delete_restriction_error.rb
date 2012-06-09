module ActiveRecord
  # This error is raised when trying to destroy a parent instance in N:1 or 1:1 associations
  # (has_many, has_one) when there is at least 1 child associated instance.
  # ex: if @project.tasks.size > 0, DeleteRestrictionError will be raised when trying to destroy @project
  class DeleteRestrictionError < ActiveRecordError #:nodoc:
    def initialize(reflection, record)
      @reflection = reflection
      @record = record
      super(basic_message)
    end

    def basic_message
      single = @reflection.class_name.to_s.underscore.gsub('_', ' ')
      if [:has_many, :has_and_belongs_to_many].include?(@reflection.macro)
        count = @record.send(@reflection.name).count
        type = count == 1 ? single : single.pluralize
        exist = (count == 1 ? 'exists' : 'exist')
        "Cannot delete record because #{count} dependent #{type} #{exist}"
      else
        "Cannot delete record because dependent #{single} exists"
      end
    end

    def detailed_message
      count = @record.send(@reflection.name).count
      examples = @record.send(@reflection.name).all(:limit => 5).map{|o| "#{o.id}: #{o.to_s}"}
      examples[4] = "...and #{count - 4} more" if count > 5
      basic_message + "\n\n\nThese include:\n#{examples.join("\n")}"
    end
  end
end
