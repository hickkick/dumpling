Sequel.migration do
    change do
      alter_table :orders do
        add_column :status, String, default: 'pending'
      end
    end
end

