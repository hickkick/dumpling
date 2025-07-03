require 'roda'
require 'dotenv/load'
require 'json'
require_relative './routes/telegram_webhook'

class App < Roda
  route do |r|
    r.on 'webhook' do
      r.run TelegramWebhook
    end

    r.root do
      "Varenuk Roda Bot 🚀"
    end
  end
end