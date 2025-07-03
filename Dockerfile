# Базовий Ruby образ
FROM ruby:3.4.1

# Оновлення системи та установка потрібних пакетів
RUN apt-get update -qq && apt-get install -y build-essential libpq-dev

# Робоча директорія всередині контейнера
WORKDIR /app

# Копіюємо гемфайли і встановлюємо залежності
COPY Gemfile Gemfile.lock ./
RUN bundle install

# Копіюємо весь код в контейнер
COPY . .

# Запускаємо скрипт, який виконує:
# - міграції
# - сид
# - вебхук
# - і старт апки
CMD ["bash", "start.sh"]
