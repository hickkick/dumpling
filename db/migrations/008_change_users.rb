Sequel.migration do
    change do
      alter_table(:users) do
        add_column :order_step, String
        add_column :phone, String
        add_column :address, String
      end
    end
  end