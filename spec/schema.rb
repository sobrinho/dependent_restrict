ActiveRecord::Schema.define(:version => 1) do
  create_table :categories do |t|
  end

  create_table :order_invoices do |t|
    t.integer :order_id
  end

  create_table :orders do |t|
    t.integer :category_id
  end
end

