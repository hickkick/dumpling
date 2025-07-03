Sequel.migration do
    change do
        create_table(:orders) do
            primary_key :id
            foreign_key :user_id, :users
            DateTime :created_at
        end
        
        
        create_table(:order_items) do
            primary_key :id
            foreign_key :order_id, :orders
            foreign_key :menu_item_id, :menu_items
            Integer :quantity
            Float :price_at_order_time
        end
    end
end