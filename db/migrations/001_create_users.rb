Sequel.migration do
    change do
      create_table(:users) do
        primary_key :id
        Integer :telegram_id, unique: true, null: false
        String :first_name
        String :last_name
        String :username
        String :language
        DateTime :created_at
        DateTime :updated_at
      end
    end
  end