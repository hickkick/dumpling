Sequel.migration do
    change do
      create_table(:cart_items) do
        primary_key :id
        foreign_key :user_id, :users
        foreign_key :menu_item_id, :menu_items
        Integer :quantity, default: 1
        DateTime :created_at
        DateTime :updated_at
      end
    end
end