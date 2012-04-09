require 'spec_helper'

DB_FILE = 'tmp/test_db'
FileUtils.mkdir_p File.dirname(DB_FILE)
FileUtils.rm_f DB_FILE

ActiveRecord::Base.establish_connection :adapter => 'sqlite3', :database => DB_FILE

load 'spec/schema.rb'

class OrderInvoice < ActiveRecord::Base
  belongs_to :order
end

class Order < ActiveRecord::Base
  belongs_to :category
  has_one :order_invoice, :dependent => :raise
end

class Category < ActiveRecord::Base
  has_many :orders, :dependent => :raise
end

describe DependentProtect do
  it 'should restrict has_many relationships' do
    category = Category.create!
    order = Order.create!(:category => category)
    lambda{category.reload.destroy}.should raise_error(ActiveRecord::DependencyError)

    order.destroy
    lambda{category.reload.destroy}.should_not raise_error
  end

  it 'should restrict has_one relationships' do
    order = Order.create!
    order_invoice = OrderInvoice.create!(:order => order)
    lambda{order.reload.destroy}.should raise_error(ActiveRecord::DependencyError)

    order_invoice.destroy
    lambda{order.reload.destroy}.should_not raise_error
  end
end

