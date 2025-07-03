require 'telegram/bot'
require 'dotenv/load'

bot = Telegram::Bot::Client.new(ENV['BOT_TOKEN'])
url = ENV['WEBHOOK_URL']

response = bot.api.set_webhook(url: url)
puts response
