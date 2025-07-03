Sequel.migration do
    change do
      alter_table(:users) do
        set_column_type :telegram_id, :Bignum
      end
    end
  end
  