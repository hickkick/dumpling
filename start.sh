#!/bin/bash

echo "👉 Running DB migrations..."
ruby run_migration_prod.rb

echo "✅ Migrations done."

echo "Start seeding db"
ruby db/seed.rb

echo "Seeding done."


echo "🌐 Setting Telegram webhook..."
ruby set_webhook.rb

echo "🚀 Starting app..."
bundle exec rackup config.ru -p $PORT
