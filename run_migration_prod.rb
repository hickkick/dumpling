require 'sequel'
require 'logger'

Sequel.extension :migration

DB = Sequel.connect(ENV['DATABASE_URL'])
DB.loggers << Logger.new($stdout)

begin
  puts "🚀 Запускаємо міграції..."
  migrations_path = File.expand_path('db/migrations', __dir__)
  Sequel::Migrator.run(DB, migrations_path)
  puts "✅ Міграції виконані успішно!"
  
  # Перевірка створених таблиць
  puts "\n📋 Список таблиць після міграції:"
  DB.tables.each { |table| puts "- #{table}" }
  
  # Перевірка структури таблиці users
  if DB.tables.include?(:users)
    puts "\n🧩 Структура таблиці users:"
    DB.schema(:users).each do |column, info|
      puts "- #{column}: #{info[:type]} #{info[:allow_null] ? 'NULL' : 'NOT NULL'}"
    end
  end

rescue => e
  puts "❌ Помилка при виконанні міграцій: #{e.message}"
  puts e.backtrace.first(5)
  exit(1)
end
