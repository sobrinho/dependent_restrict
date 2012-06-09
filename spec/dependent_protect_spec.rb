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
  has_one :order_invoice, :dependent => :restrict
  def to_s
    "Order #{id}"
  end
end

class Category < ActiveRecord::Base
  has_many :orders, :dependent => :restrict
  def to_s
    "Category #{id}"
  end
end

describe DependentProtect do
  it 'should restrict has_many relationships' do
    category = Category.create!
    5.times { Order.create!(:category => category) }
    lambda{category.reload.destroy}.should raise_error(ActiveRecord::DeleteRestrictionError, 'Cannot delete record because 5 dependent orders exist')
    begin
      category.destroy
    rescue ActiveRecord::DeleteRestrictionError => e
      e.detailed_message.should == "Cannot delete record because 5 dependent orders exist\n\n\nThese include:\n1: Order 1\n2: Order 2\n3: Order 3\n4: Order 4\n5: Order 5"
    end
    1.times { Order.create!(:category => category) }
    begin
      category.destroy
    rescue ActiveRecord::DeleteRestrictionError => e
      e.detailed_message.should == "Cannot delete record because 6 dependent orders exist\n\n\nThese include:\n1: Order 1\n2: Order 2\n3: Order 3\n4: Order 4\n...and 2 more"
    end

    Order.destroy_all
    lambda{category.reload.destroy}.should_not raise_error
  end

  it 'should restrict has_one relationships' do
    order = Order.create!
    order_invoice = OrderInvoice.create!(:order => order)
    lambda{order.reload.destroy}.should raise_error(ActiveRecord::DeleteRestrictionError, 'Cannot delete record because dependent order invoice exists')

    order_invoice.destroy
    lambda{order.reload.destroy}.should_not raise_error
  end
end

