require 'telegram/bot'
require_relative '../services/telegram_handler'

class TelegramWebhook < Roda
  plugin :json
  plugin :error_handler
  
  # Логування всіх помилок
  error do |e|
    puts "=== WEBHOOK ERROR ==="
    puts "Error: #{e.message}"
    puts "Class: #{e.class}"
    puts "Backtrace:"
    puts e.backtrace.first(10)
    puts "========================"
    
    response.status = 500
    {
      ok: false,
      error: e.message,
      type: e.class.name,
      timestamp: Time.now.iso8601
    }
  end
  
  route do |r|
    r.post do
      begin
        # Читаємо body
        body = request.body.read
        puts "=== WEBHOOK REQUEST ==="
        puts "Body: #{body}"
        puts "Content-Type: #{request.content_type}"
        
        # Парсимо JSON
        if body.empty?
          puts "Empty request body"
          { ok: true, message: "Empty request" }
        else
          webhook_data = JSON.parse(body)
          puts "Parsed JSON successfully"
          
          # Передаємо в handler
          bot = Telegram::Bot::Client.new(ENV['BOT_TOKEN'])
          handler = TelegramHandler.new(bot)
          result = handler.process(webhook_data)
          puts "Handler result: #{result.inspect}"
          
          result
        end
        
      rescue JSON::ParserError => e
        puts "JSON Parse Error: #{e.message}"
        puts "Raw body: #{body.inspect}"
        
        response.status = 400
        {
          ok: false,
          error: "Invalid JSON",
          raw_body: body,
          timestamp: Time.now.iso8601
        }
        
      rescue => e
        puts "Unexpected error in webhook: #{e.message}"
        puts e.backtrace.first(5)
        
        response.status = 500
        {
          ok: false,
          error: e.message,
          type: e.class.name,
          timestamp: Time.now.iso8601
        }
      end
    end
    
    r.get do
      # GET запит для перевірки що webhook працює
      {
        ok: true,
        message: "Telegram webhook is running",
        timestamp: Time.now.iso8601
      }
    end
  end
end