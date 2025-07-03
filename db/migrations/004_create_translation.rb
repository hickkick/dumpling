Sequel.migration do
    change do
      create_table(:translations) do
        primary_key :id
        String :locale, null: false
        String :key, null: false
        String :value, text: true, null: false
        unique [:locale, :key]
      end
    end
  end
  