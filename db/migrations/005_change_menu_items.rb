Sequel.migration do
    change do
      alter_table(:menu_items) do
        add_column :name_uk, String
        add_column :name_pl, String
        add_column :name_en, String
        add_column :name_ru, String
        add_column :name_by, String
        add_column :created_at, DateTime
        add_column :updated_at, DateTime
  
        drop_column :name
        drop_column :description
      end
    end
  end