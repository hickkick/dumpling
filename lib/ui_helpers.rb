require_relative '../models/translation'

module UiHelpers
    def available_locales
      Translation.where(key: 'name')
                 .select(:locale, :value)
                 .map { |t| [t.locale, t.value] }
                 .to_h
    end
  
    def language_keyboard
      buttons = available_locales.values

      keyboard = buttons.map do |label|
        locale = available_locales.invert[label]
        [Telegram::Bot::Types::InlineKeyboardButton.new(
          text: label,
          callback_data: "lang:#{locale}"
        )]
      end
    
      Telegram::Bot::Types::InlineKeyboardMarkup.new(
        inline_keyboard: keyboard
      )
    end
  
    def menu_keyboard(locale)
      items = DB[:menu_items].all

      buttons = items.map do |item|
        text = item[:"name_#{locale}"] || item[:name_uk]
        [
          Telegram::Bot::Types::InlineKeyboardButton.new(
            text: "#{text} — #{item[:price]} zł/kg",
            callback_data: "menu_item:#{item[:id]}"
          )
        ]
      end
    
      Telegram::Bot::Types::InlineKeyboardMarkup.new(
        inline_keyboard: buttons
      )
    end
  
    def cart_keyboard(locale)
      buttons = [
        Telegram::Bot::Types::KeyboardButton.new(text: Translator.t(locale, 'make_order')),
        Telegram::Bot::Types::KeyboardButton.new(text: Translator.t(locale, 'clear_cart')),
        Telegram::Bot::Types::KeyboardButton.new(text: '/menu')
      ]
    
      Telegram::Bot::Types::ReplyKeyboardMarkup.new(
        keyboard: buttons.map { |btn| [btn] }, # робимо масив рядків кнопок
        resize_keyboard: true,
        one_time_keyboard: true
      )
    end

    def main_menu_keyboard
      buttons = [
        ['/menu', '/cart'],
        ['/orders', '/start']
      ].map do |row|
        row.map { |label| Telegram::Bot::Types::KeyboardButton.new(text: label) }
      end
    
      Telegram::Bot::Types::ReplyKeyboardMarkup.new(
        keyboard: buttons,
        resize_keyboard: true,
        one_time_keyboard: false
      )
    end

    def admin_keyboard
      keyboard = Telegram::Bot::Types::InlineKeyboardMarkup.new(
      inline_keyboard: [
        [
          Telegram::Bot::Types::InlineKeyboardButton.new(text: 'Нові замовлення', callback_data: 'filter_pending'),
          Telegram::Bot::Types::InlineKeyboardButton.new(text: 'Прийняті', callback_data: 'filter_confirmed'),
          Telegram::Bot::Types::InlineKeyboardButton.new(text: 'Відправлені', callback_data: 'filter_sent')
        ]
      ]
    )
    end

    def inline_buttons_for_order(order)
      case order.status
      when 'pending'
        [
          [
            { text: "✅ Підтвердити", callback_data: "order_#{order.id}_confirm" },
            { text: "❌ Скасувати", callback_data: "order_#{order.id}_cancel" }
          ]
        ]
      when 'confirmed'
        [
          [
            { text: "🚚 Відправлено", callback_data: "order_#{order.id}_send" }
          ]
        ]
      else
        [] # Для sent/cancelled — без кнопок
      end
    end
end
  