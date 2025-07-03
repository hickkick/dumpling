Sequel.migration do
    change do
      create_table(:menu_items) do
        primary_key :id
        String :name
        String :description
        Integer :price
      end
    end
  end