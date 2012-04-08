require 'spec_helper'

DB_FILE = 'tmp/test_db'
FileUtils.mkdir_p File.dirname(DB_FILE)
FileUtils.rm_f DB_FILE

ActiveRecord::Base.establish_connection :adapter => 'sqlite3', :database => DB_FILE

load 'db/schema.rb'

class Order < ActiveRecord::Base
  belongs_to :category
end

class Category < ActiveRecord::Base
  has_many :orders, :dependent => :raise
end

describe 'restricted' do
  it 'should work' do
    category = Category.create!
    model = Order.create!(:category => category)
    lambda{category.reload.destroy}.should raise_error(ActiveRecord::DependencyError)

    model.destroy
    lambda{category.reload.destroy}.should_not raise_error
  end
end

