#encoding: utf-8
require 'spec_helper'

DB_FILE = 'tmp/test_db'
FileUtils.mkdir_p File.dirname(DB_FILE)
FileUtils.rm_f DB_FILE

ActiveRecord::Base.establish_connection :adapter => 'sqlite3', :database => DB_FILE

load 'spec/schema.rb'


describe DependentRestrict do

  context 'when associations are defined' do
    before do
      class OrderInvoice < ActiveRecord::Base
        belongs_to :order
      end

      class Order < ActiveRecord::Base
        belongs_to :category

        def to_s
          "Order #{id}"
        end
      end

      class Category < ActiveRecord::Base
        def to_s
          "Category #{id}"
        end
      end
    end

    after do
      %w(OrderInvoice Order Category).each { |klass| Object.send(:remove_const, klass) }
    end


    context 'when not restricting' do
      it 'should allow creating reflections' do
        expect {
          class Order < ActiveRecord::Base
            has_one :order_invoice
          end

          class Category < ActiveRecord::Base
            has_many :orders do
              def active
                self.select(&:active?)
              end
            end
          end
        }.to_not raise_error
      end
    end


    context 'when restricting with exception' do
      before do
        class Order < ActiveRecord::Base
          has_one :order_invoice, :dependent => :restrict_with_exception
        end

        class Category < ActiveRecord::Base
          has_many :orders, :dependent => :restrict_with_exception do
            def active
              self.select(&:active?)
            end
          end
        end
      end

      it 'should restrict has_many relationships' do
        category = Category.create!
        5.times { Order.create!(:category => category) }
        expect { category.reload.destroy }.to raise_error(
                                                  ActiveRecord::DetailedDeleteRestrictionError,
                                                  'Cannot delete record because 5 dependent orders exist'
                                              )
        begin
          category.destroy
        rescue ActiveRecord::DetailedDeleteRestrictionError => e
          e.detailed_message.should == "Cannot delete record because 5 dependent orders exist\n\n\nThese include:\n1: Order 1\n2: Order 2\n3: Order 3\n4: Order 4\n5: Order 5"
        end
        1.times { Order.create!(:category => category) }
        begin
          category.destroy
        rescue ActiveRecord::DetailedDeleteRestrictionError => e
          e.detailed_message.should == "Cannot delete record because 6 dependent orders exist\n\n\nThese include:\n1: Order 1\n2: Order 2\n3: Order 3\n4: Order 4\n...and 2 more"
        end

        Order.destroy_all
        expect { category.reload.destroy }.to_not raise_error
      end

      it 'should restrict has_one relationships' do
        order = Order.create!
        order_invoice = OrderInvoice.create!(:order => order)
        expect { order.reload.destroy }.to raise_error(
                                               ActiveRecord::DetailedDeleteRestrictionError,
                                               'Cannot delete record because dependent order invoice exists'
                                           )

        order_invoice.destroy
        expect { order.reload.destroy }.to_not raise_error
      end

      it 'should still filter active' do
        category = Category.create!
        3.times { Order.create!(:category => category, :active => true) }
        2.times { Order.create!(:category => category, :active => false) }
        category.orders.active.count.should == 3

        Category.delete_all
        Order.delete_all
      end

      context "using i18n" do
        before do
          I18n.backend.store_translations(:br, {
            :dependent_restrict => {
              :basic_message => {
                :one => 'Não pode ser excluído pois um(a) %{name} relacionado(a) foi encontrado(a)',
                :others => 'Não pode ser excluído pois %{count} %{name} relacionados(as) foram encontrados(as)'
              },
              :detailed_message => {
                :and_more => "e mais %{count}",
                :includes => "Incluindo"
              }
            },
            :activerecord => {
              :models => {
                :order => {
                  :one => "Pedido",
                  :other => "Pedidos"
                },
                :order_invoice => {
                  :one => "Ordem de pedido"
                }
              }
            }
          })

          I18n.locale = :br
        end

        after do
          I18n.locale = :en
        end

        it 'should restrict has_many relationships' do

          category = Category.create!
          5.times { Order.create!(:category => category) }
          expect { category.reload.destroy }.to raise_error(
            ActiveRecord::DetailedDeleteRestrictionError,
            'Não pode ser excluído pois 5 pedidos relacionados(as) foram encontrados(as)'
          )
          begin
            category.destroy
          rescue ActiveRecord::DetailedDeleteRestrictionError => e
            e.detailed_message.should == "Não pode ser excluído pois 5 pedidos relacionados(as) foram encontrados(as)\n\n\nIncluindo:\n13: Order 13\n14: Order 14\n15: Order 15\n16: Order 16\n17: Order 17"
          end
          1.times { Order.create!(:category => category) }
          begin
            category.destroy
          rescue ActiveRecord::DetailedDeleteRestrictionError => e
            e.detailed_message.should == "Não pode ser excluído pois 6 pedidos relacionados(as) foram encontrados(as)\n\n\nIncluindo:\n13: Order 13\n14: Order 14\n15: Order 15\n16: Order 16\n...e mais 2"
          end

          Order.destroy_all
          expect { category.reload.destroy }.to_not raise_error
        end

        it 'should restrict has_one relationships' do
          order = Order.create!
          order_invoice = OrderInvoice.create!(:order => order)
          expect { order.reload.destroy }.to raise_error(
            ActiveRecord::DetailedDeleteRestrictionError,
            'Não pode ser excluído pois um(a) ordem de pedido relacionado(a) foi encontrado(a)'
          )

          order_invoice.destroy
          expect { order.reload.destroy }.to_not raise_error
        end
      end
    end


    context 'when restricting with error' do
      before do
        class Order < ActiveRecord::Base
          has_one :order_invoice, :dependent => :restrict_with_error
        end

        class Category < ActiveRecord::Base
          has_many :orders, :dependent => :restrict_with_error do
            def active
              self.select(&:active?)
            end
          end
        end
      end

      it 'should restrict has_many relationships' do
        category = Category.create!
        Category.count.should == 1
        5.times { Order.create!(:category => category) }
        category.destroy
        Category.count.should == 1
        Order.destroy_all
        category.reload.destroy
        Category.count.should == 0
      end

      it 'should restrict has_one relationships' do
        order = Order.create!
        Order.count.should == 1
        order_invoice = OrderInvoice.create!(:order => order)
        order.reload.destroy
        Order.count.should == 1

        order_invoice.destroy
        order.reload.destroy
        Order.count.should == 0
      end
    end
  end


end

