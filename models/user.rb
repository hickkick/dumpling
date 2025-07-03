require_relative '../db'

class User < Sequel::Model
  # Базові методи без валідації для debug
  
  def full_name
    [first_name, last_name].compact.join(' ')
  end
  
  def display_name
    username ? "@#{username}" : full_name
  end
  
  # Простий метод створення без валідації
  def self.create_telegram_user(telegram_data)
    create(
      telegram_id: telegram_data['id'].to_i,
      first_name: telegram_data['first_name'] || 'Unknown',
      last_name: telegram_data['last_name'],
      username: telegram_data['username'],
      language: telegram_data['language_code'] || 'uk',
      created_at: Time.now,
      updated_at: Time.now
    )
  end
  
  # Статистика
  def self.stats
    {
      total: count,
      recent: where(created_at: (Time.now - 86400)..Time.now).count
    }
  end
end