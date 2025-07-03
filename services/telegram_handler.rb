require_relative '../models/user'
require_relative '../models/menu_item'
require_relative '../lib/translator'
require_relative '../lib/ui_helpers'


class TelegramHandler
  include UiHelpers

  def initialize(bot)
    @bot = bot
  end

  def process(webhook_data)
    puts "=== TELEGRAM WEBHOOK DATA ==="
    puts webhook_data.inspect
    
    if webhook_data['callback_query']
      callback = webhook_data['callback_query']
      data = callback['data']
      from = callback['from']
      puts "f" * 80
      puts from
      user = find_or_create_user(from)
      puts '*' * 80
      puts "Callback data received: #{data}"

      #обробка адмінських списків
      case data
      when /filter_(\w+)$/
        status = Regexp.last_match(1)
        
        @bot.api.answer_callback_query(callback_query_id: callback['id'], text: "Loading...")
        begin
          @bot.api.edit_message_reply_markup(
            chat_id: callback['message']['chat']['id'],
            message_id: callback['message']['message_id'],
            reply_markup: nil
          )
        rescue Telegram::Bot::Exceptions::ResponseError => e
          puts "⚠️ Не вдалося: #{e.message}"
        end

        @bot.api.delete_message(
          chat_id: callback['message']['chat']['id'],
          message_id: callback['message']['message_id']
        )
        handle_filtered_orders(user, status, 1)
        return { ok: true, message: "Callback processed" }
      
      when /filter_(\w+)_page:(\d+)/
        status = Regexp.last_match(1)
        page = Regexp.last_match(2).to_i
        

        @bot.api.answer_callback_query(callback_query_id: callback['id'], text: "Loading...")
        begin
          @bot.api.edit_message_reply_markup(
            chat_id: callback['message']['chat']['id'],
            message_id: callback['message']['message_id'],
            reply_markup: nil
          )
        rescue Telegram::Bot::Exceptions::ResponseError => e
          puts "⚠️ Не вдалося: #{e.message}"
        end

        @bot.api.delete_message(
          chat_id: callback['message']['chat']['id'],
          message_id: callback['message']['message_id']
        )
        handle_filtered_orders(user, status, page)
        return { ok: true, message: "Callback processed" }
      when /^confirm_order:(\d+)$/
        order_id = $1.to_i
        @bot.api.answer_callback_query(callback_query_id: callback['id'], text: "PROCESSING...")

        # begin
        #   puts callback['message']['chat']['id']
        #   @bot.api.edit_message_reply_markup(
        #     chat_id: callback['message']['chat']['id'],
        #     message_id: callback['message']['message_id'],
        #     reply_markup: nil
        #   )
        # rescue Telegram::Bot::Exceptions::ResponseError => e
        #   puts "⚠️ Не вдалося: #{e.message}"
        # end
        # @bot.api.delete_message(
        #   chat_id: callback['message']['chat']['id'],
        #   message_id: callback['message']['message_id']
        # )

        confirm_order(order_id, from)

        return { ok: true, message: "Callback processed" }
      when /^cancel_order:(\d+)$/
        order_id = $1.to_i
        @bot.api.answer_callback_query(callback_query_id: callback['id'], text: "PROCESSING...")
        # begin
        #   @bot.api.edit_message_reply_markup(
        #     chat_id: callback['message']['chat']['id'],
        #     message_id: callback['message']['message_id'],
        #     reply_markup: nil
        #   )
        # rescue Telegram::Bot::Exceptions::ResponseError => e
        #   puts "⚠️ Не вдалося: #{e.message}"
        # end
        cancel_order(order_id, from)
        # @bot.api.delete_message(
        #   chat_id: callback['message']['chat']['id'],
        #   message_id: callback['message']['message_id']
        # )
        return { ok: true, message: "Callback processed" }
      when /^send_order:(\d+)$/
        order_id = $1.to_i
         
        @bot.api.answer_callback_query(callback_query_id: callback['id'], text: "PROCESSING...")
        # begin
        #   @bot.api.edit_message_reply_markup(
        #     chat_id: callback['message']['chat']['id'],
        #     message_id: callback['message']['message_id'],
        #     reply_markup: nil
        #   )
        # rescue Telegram::Bot::Exceptions::ResponseError => e
        #   puts "⚠️ Не вдалося: #{e.message}"
        # end
        send_order(order_id, from) 
        return { ok: true, message: "Callback processed" }
      end
      if data.start_with?('lang:')
        new_locale = data.split(':').last
        begin
          @bot.api.edit_message_reply_markup(
            chat_id: callback['message']['chat']['id'],
            message_id: callback['message']['message_id'],
            reply_markup: nil
          )
        rescue Telegram::Bot::Exceptions::ResponseError => e
          puts "⚠️ Не вдалося: #{e.message}"
        end

        @bot.api.answer_callback_query(
          callback_query_id: callback['id'],
          text: Translator.t(user.language || 'pl', 'language_changed')
        )
        @bot.api.delete_message(
          chat_id: callback['message']['chat']['id'],
          message_id: callback['message']['message_id']
        )
        user.update(language: new_locale)
      
        @bot.api.send_message(
          chat_id: user.telegram_id,
          text: Translator.t(new_locale, 'make_order'),
          reply_markup: menu_keyboard(new_locale)
        )
      
        return { ok: true, message: "Callback processed" }
      end

      if data.start_with?('orders_page:')
        page = data.split(':').last.to_i

        begin
          @bot.api.edit_message_reply_markup(
            chat_id: callback['message']['chat']['id'],
            message_id: callback['message']['message_id'],
            reply_markup: nil
          )
        rescue Telegram::Bot::Exceptions::ResponseError => e
          puts "⚠️ Не вдалося оновити клавіатуру: #{e.message}"
        end

        @bot.api.answer_callback_query(callback_query_id: callback['id'], text: Translator.t(user.language || 'pl', 'switching_page'))

        handle_orders(user, page)
        return { ok: true, message: "Callback processed" }
      end

      if data.start_with?('menu_item:')
        id = data.split(':')[1].to_i
        item = DB[:menu_items][id: id]
    
        if item
          existing = DB[:cart_items][user_id: user.id, menu_item_id: id]
          if existing
            DB[:cart_items].where(id: existing[:id]).update(
              quantity: existing[:quantity] + 1,
              updated_at: Time.now
            )
          else
            DB[:cart_items].insert(
              user_id: user.id,
              menu_item_id: id,
              quantity: 1,
              created_at: Time.now,
              updated_at: Time.now
            )
          end
    
          @bot.api.send_message(
            chat_id: user.telegram_id,
            text: "#{Translator.t(user.language, 'add_to_cart')} '/cart' #{item[:"name_#{user.language}"] || item[:name_pl]}"
          )
        end
    
        @bot.api.answer_callback_query(callback_query_id: callback['id'])  
        return { ok: true, message: "Callback processed" }

      elsif data.start_with?('order_details:')
        order_id = data.split(':').last.to_i
        handle_order_details(user, order_id)
    
        @bot.api.answer_callback_query(callback_query_id: callback['id'])

      elsif data.start_with?('repeat_order:')
        order_id = data.split(':').last.to_i
        repeat_order(user, order_id)
        @bot.api.answer_callback_query(callback_query_id: callback['id'], text: Translator.t(user.language || 'pl', 'add_to_cart'))
      else
        @bot.api.answer_callback_query(callback_query_id: callback['id'], text: Translator.t(user.language || 'pl', 'unknown_action'))
      end
    end
    # Перевірка наявності повідомлення
    unless webhook_data['message']
      puts "No message in webhook data"
      return { ok: true, message: "No message data" }
    end
    
    message = webhook_data['message']
    user_data = message['from']
    
    unless user_data
      puts "No user data in message"
      return { ok: true, message: "No user data" }
    end
    
    puts "=== USER DATA FROM TELEGRAM ==="
    puts user_data.inspect
    
    begin
      # Спробуємо знайти існуючого користувача
      existing_user = User.find(telegram_id: user_data['id'])
      
      if existing_user
        puts "Found existing user: #{existing_user.id}"
        # Оновлюємо дані користувача
        existing_user.update(
          first_name: user_data['first_name'],
          last_name: user_data['last_name'],
          username: user_data['username'],
          # language: user_data['language_code'] || existing_user.language || 'pl',
          updated_at: Time.now
        )
        user = existing_user
      else
        puts "Creating new user..."
        # Створюємо нового користувача з валідацією даних
        user_params = {
          telegram_id: user_data['id'].to_i,
          first_name: user_data['first_name'] || 'Unknown',
          last_name: user_data['last_name'],
          username: user_data['username'],
          language: user_data['language_code'] || 'pl',
          created_at: Time.now,
          updated_at: Time.now
        }
        
        puts "User params: #{user_params.inspect}"
        user = User.create(user_params)
      end
      
      puts "User processed successfully: #{user.id}"
      
      # Обробка повідомлення
      process_message(message, user)
      
      {
        ok: true,
        user_id: user.id,
        message: "User and message processed successfully"
      }
      
    rescue => e
      puts "Error processing user: #{e.message}"
      puts e.backtrace.first(10)
      
      # Повертаємо помилку для debug
      {
        ok: false,
        error: e.message,
        user_data: user_data,
        class: e.class.name
      }
    end
  end
  
  private
  
  def process_message(message, user)
    puts "$BOT is: #{@bot.inspect}"
    puts "==========="
    text = message['text']
    
    puts "Processing message: #{text} from user #{user.id}"
    if user.order_step == 'waiting_for_phone'
      if message['contact']
        user.update(phone: message['contact']['phone_number'], order_step: 'waiting_for_address')
        @bot.api.send_message(chat_id: user.telegram_id, text: Translator.t(user.language || 'pl', 'enter_address'))
      elsif text =~ /\A\+?[\d\s\-]{9,15}\z/
        user.update(phone: text, order_step: 'waiting_for_address')
        @bot.api.send_message(chat_id: user.telegram_id, text: Translator.t(user.language || 'pl', 'enter_address'))
      else
        @bot.api.send_message(
          chat_id: user.telegram_id,
          text: Translator.t(user.language || 'pl', 'share_phone_tip'),
          reply_markup: Telegram::Bot::Types::ReplyKeyboardMarkup.new(
            keyboard: [[Telegram::Bot::Types::KeyboardButton.new(text: Translator.t(user.language || 'pl', 'share_phone'), request_contact: true)]],
            resize_keyboard: true,
            one_time_keyboard: true
          )
        )
      end
      return
    end
    if user.order_step == 'waiting_for_address'
      puts '5' * 80
      puts message
      user.update(address: text, order_step: nil)
    
      # створюємо замовлення і відправляємо адміну
      order_id = create_order_from_cart(user)
    
      order_summary = build_order_summary(user, order_id)
    
      # TODO: Заміни на свій telegram_id
      admin_id = ENV['ADMIN_CHAT_ID'] || '123456789'
    
      @bot.api.send_message(
        chat_id: admin_id,
        text: "#{Translator.t(user.language || 'pl', 'new_order_from')} #{user.first_name}:\n#{order_summary}"
      )
    
      @bot.api.send_message(
        chat_id: user.telegram_id,
        text: Translator.t(user.language || 'pl', 'order_placed'),
        reply_markup: main_menu_keyboard
      )
    
      return
    end
    
    return unless text

    case text
    when '/start'
      puts "Start command from user #{user.telegram_id}"
      puts "User language is: #{user.language}"
      @bot.api.send_message(
        chat_id: user.telegram_id,
        text: Translator.t(user.language || 'pl', 'welcome'),
        reply_markup: language_keyboard
      )
    when '/menu'
      @bot.api.send_message(
        chat_id: user.telegram_id,
        text: Translator.t(user.language, 'menu_title'),
        reply_markup: menu_keyboard(user.language)
      )
    when '/cart'
      # cart_items = DB[:cart_items].where(user_id: user.id).all
    
      # if cart_items.empty?
      #   text = Translator.t(user.language, 'cart_empty') # плейсхолдер на перед
      # else
      #   lines = cart_items.map do |ci|
      #     item = DB[:menu_items][id: ci[:menu_item_id]]
      #     name = item[:"name_#{user.language}"] || item[:name_uk]
      #     price = item[:price]
      #     "#{name} — #{ci[:quantity]} x #{price} zł = #{ci[:quantity] * price} zł"
      #   end
    
      #   total = cart_items.sum do |ci|
      #     item = DB[:menu_items][id: ci[:menu_item_id]]
      #     ci[:quantity] * item[:price]
      #   end
    
      #   text = "#{Translator.t(user.language, 'cart_title')}\n" + lines.join("\n") + "\n\n#{Translator.t(user.language, 'total')} #{total} zł"
      # end
      cart_items = DB[:cart_items].where(user_id: user.id).all

      if cart_items.empty?
        text = "#{Translator.t(user.language, 'cart_empty')} /menu"
      else
        delivery_price = 10
        total_quantity = cart_items.sum { |ci| ci[:quantity] }

        lines = cart_items.map do |ci|
          item = DB[:menu_items][id: ci[:menu_item_id]]
          name = item[:"name_#{user.language}"] || item[:name_uk]
          price = item[:price]
          "#{name} — #{ci[:quantity]} x #{price} zł = #{ci[:quantity] * price} zł"
        end

        total = cart_items.sum do |ci|
          item = DB[:menu_items][id: ci[:menu_item_id]]
          ci[:quantity] * item[:price]
        end

        # Додаємо доставку, якщо кількість < 3
        if total_quantity < 3
          total += delivery_price
          lines << "#{Translator.t(user.language, 'delivery')} #{delivery_price} zł"
        end

        text = "#{Translator.t(user.language, 'cart_title')}\n" +
              lines.join("\n") +
              "\n\n#{Translator.t(user.language, 'total')} #{total.round(2)} zł"
      end

    
      @bot.api.send_message(
        chat_id: user.telegram_id,
        text: text,
        reply_markup: cart_keyboard(user.language)
      )
      
    when Translator.t(user.language, 'clear_cart')
      DB[:cart_items].where(user_id: user.id).delete
      @bot.api.send_message(chat_id: user.telegram_id, text: "#{Translator.t(user.language, 'cart_empty')}! #{Translator.t(user.language, 'menu_title')} /menu")

    when Translator.t(user.language, 'make_order')
      cart_items = DB[:cart_items].where(user_id: user.id).all
    
      if cart_items.empty?
        @bot.api.send_message(chat_id: user.telegram_id, text: "#{Translator.t(user.language, 'cart_empty')}! #{Translator.t(user.language, 'menu_title')} /menu")
      else
        #провалюємся до замовлення > телефон
        user.update(order_step: 'waiting_for_phone')

        @bot.api.send_message(
          chat_id: user.telegram_id,
          text: Translator.t(user.language, 'share_phone_tip'),
          reply_markup: Telegram::Bot::Types::ReplyKeyboardMarkup.new(
            keyboard: [[Telegram::Bot::Types::KeyboardButton.new(text: Translator.t(user.language, 'share_phone'), request_contact: true)]],
            resize_keyboard: true,
            one_time_keyboard: true
          )
        )
      end
    when '/orders'
      handle_orders(user)
    when '/admin'
      if admin?(user.telegram_id)
        @bot.api.send_message(
          chat_id: user.telegram_id,
          text: Translator.t(user.language || 'pl', 'choose_filter'),
          reply_markup: admin_keyboard
        )
      else
        @bot.api.send_message(
          chat_id: user.telegram_id,
          text: Translator.t(user.language || 'pl', 'no_access')
        )
      end
    when '/help'
      puts "Help command from user #{user.telegram_id}"
      @bot.api.send_message(
        chat_id: user[:telegram_id],
        text: Translator.t(user.language || 'pl', 'instruction'),
        reply_markup: main_menu_keyboard
      )
    else
      puts "Regular message: #{text}"
      @bot.api.send_message(
      chat_id: user[:telegram_id],
      text: Translator.t(user.language || 'pl', 'unknown_command'),
      reply_markup: main_menu_keyboard
    )
    end
  end

  def find_or_create_user(user_data)
    existing_user = User.find(telegram_id: user_data['id'])
    if existing_user
      existing_user.update(
        first_name: user_data['first_name'],
        last_name: user_data['last_name'],
        username: user_data['username'],
        # language: user_data['language_code'] || existing_user.language || 'uk',
        updated_at: Time.now
      )
      existing_user
    else
      User.create(
        telegram_id: user_data['id'],
        first_name: user_data['first_name'] || 'Unknown',
        last_name: user_data['last_name'],
        username: user_data['username'],
        language: user_data['language_code'] || 'uk',
        created_at: Time.now,
        updated_at: Time.now
      )
    end
  end
  def repeat_order(user, order_id)
    order_items = DB[:order_items].where(order_id: order_id).all
  
    return false if order_items.empty?
  
    order_items.each do |oi|
      # додаємо у кошик
      existing = DB[:cart_items][user_id: user.id, menu_item_id: oi[:menu_item_id]]
      if existing
        DB[:cart_items].where(id: existing[:id]).update(
          quantity: existing[:quantity] + oi[:quantity],
          updated_at: Time.now
        )
      else
        DB[:cart_items].insert(
          user_id: user.id,
          menu_item_id: oi[:menu_item_id],
          quantity: oi[:quantity],
          created_at: Time.now,
          updated_at: Time.now
        )
      end
    end
  
    true
  end
  def build_order_summary(user, order_id)
    items = DB[:order_items].where(order_id: order_id).all
    delivery_price = 10
    total_quantity = items.sum { |oi| oi[:quantity] }
    delivery_fee = total_quantity < 3 ? delivery_price : 0

    lines = items.map do |oi|
      item = DB[:menu_items][id: oi[:menu_item_id]]
      "#{item[:name_uk]} — #{oi[:quantity]} x #{oi[:price_at_order_time]} zł"
    end
  
    items_total = items.sum { |oi| oi[:quantity] * oi[:price_at_order_time] }
    total = items_total + delivery_fee
    delivery_line = delivery_fee > 0 ? "\n#{Translator.t(user.language || 'pl', 'delivery')} #{delivery_fee} zł" : ''

  
    <<~MSG
      #{Translator.t(user.language, 'phone_label')} #{user.phone}
      #{Translator.t(user.language, 'address_label')} #{user.address}
  
      #{Translator.t(user.language, 'order_label')}
      #{lines.join("\n")}#{delivery_line}
  
      #{Translator.t(user.language, 'total_label')} #{total}₴
    MSG
  end
  def create_order_from_cart(user)
        cart_items = DB[:cart_items].where(user_id: user.id).all
        order_id = DB[:orders].insert(user_id: user.id, created_at: Time.now, updated_at: Time.now)
        cart_items.each do |ci|
          item = DB[:menu_items][id: ci[:menu_item_id]]
          DB[:order_items].insert(order_id: order_id, menu_item_id: ci[:menu_item_id], quantity: ci[:quantity], price_at_order_time: item[:price])
        end
        DB[:cart_items].where(user_id: user.id).delete
        order_id
  end
  def handle_orders(user, page = 1)
    per_page = 3
    offset = (page - 1) * per_page

    orders_dataset = DB[:orders].where(user_id: user[:id])
    total_orders = orders_dataset.count
    orders = orders_dataset.reverse(:created_at).limit(per_page).offset(offset).all

    if orders.empty?
      @bot.api.send_message(chat_id: user[:telegram_id], text: Translator.t(user.language || 'pl', 'no_orders_yet'))
      return
    end

    orders.each do |order|
      # items = DB[:order_items].where(order_id: order[:id]).all
      # total_price = items.sum { |item| item[:quantity] * item[:price_at_order_time] }
      items = DB[:order_items].where(order_id: order[:id]).all
      total_quantity = items.sum { |item| item[:quantity] }
      delivery_fee = total_quantity < 3 ? 10 : 0
      total_price = items.sum { |item| item[:quantity] * item[:price_at_order_time] } + delivery_fee

      text = <<~MSG
        #{Translator.t(user.language, 'order_label')} ##{order[:id]}
        📅 #{order[:created_at].strftime('%Y-%m-%d %H:%M')}
        #{Translator.t(user.language, 'total_label')} #{total_price.round(2)} zł
        #{Translator.t(user.language, 'status')} #{status_text(order[:status],user)}
      MSG

      kb = [
        [Telegram::Bot::Types::InlineKeyboardButton.new(text: "#{Translator.t(user.language || 'pl', 'repeat')}", callback_data: "repeat_order:#{order[:id]}")],
        [Telegram::Bot::Types::InlineKeyboardButton.new(text: "#{Translator.t(user.language || 'pl', 'details')}", callback_data: "order_details:#{order[:id]}")]
      ]

      markup = Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: kb)

      @bot.api.send_message(chat_id: user[:telegram_id], text: text.strip, reply_markup: markup)
    end

    # Після виводу замовлень — кнопки пагінації
    buttons = []
    buttons << Telegram::Bot::Types::InlineKeyboardButton.new(text: Translator.t(user.language || 'pl', 'previous'), callback_data: "orders_page:#{page - 1}") if page > 1
    if total_orders > offset + orders.length
      buttons << Telegram::Bot::Types::InlineKeyboardButton.new(text: Translator.t(user.language || 'pl', 'next'), callback_data: "orders_page:#{page + 1}")
    end

    unless buttons.empty?
      markup = Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: [buttons])
      @bot.api.send_message(chat_id: user[:telegram_id], text: "#{Translator.t(user.language || 'pl', 'page')} #{page}", reply_markup: markup)
    end
  end
  def status_text(status, user)
    {
      'pending' => Translator.t(user.language || 'pl', 'status_pending'),
      'confirmed' => Translator.t(user.language || 'pl', 'status_confirmed'),
      'preparing' => 'Готується',
      'sent' => Translator.t(user.language || 'pl', 'status_shipped'),
      'cancelled' => Translator.t(user.language || 'pl', 'status_canceled'),
      'done' => 'Доставлено'
    }[status] || Translator.t(user.language || 'pl', 'status_unknown')
  end
  def handle_order_details(user, order_id)
    items = DB[:order_items].where(order_id: order_id).all
  
    return @bot.api.send_message(chat_id: user[:telegram_id], text: Translator.t(user.language || 'pl', 'order_not_found')) if items.empty?
  
    text = "#{Translator.t(user.language || 'pl', 'order_details')}#{order_id}\n"
    menu_items = DB[:menu_items].all.to_h { |m| [m[:id], m] }

    items.each do |item|
      menu = menu_items[item[:menu_item_id]]
      name = menu["name_#{user[:language] || 'pl'}".to_sym]
      text += "- #{name} x#{item[:quantity]} = #{item[:price_at_order_time] * item[:quantity]} zł\n"
    end
  
    @bot.api.send_message(chat_id: user[:telegram_id], text: text)
  end
  def admin?(telegram_id)
    admin_ids = (ENV['ADMIN_CHAT_IDS'] || '').split(',').map(&:strip)
    admin_ids.include?(telegram_id.to_s)
  end
  def filter_orders_by_status(status, page = 1, per_page = 3)
    offset = (page - 1) * per_page
    dataset = DB[:orders]
      .where(status: status)
      .join(:users, id: :user_id)
      .reverse_order(:created_at)
      .select_all(:orders)
      .select_append(
        Sequel[:users][:first_name],
        Sequel[:users][:last_name],
        Sequel[:users][:username],
        Sequel[:users][:phone],
        Sequel[:users][:address]
      )
  
    total = dataset.count
    orders = dataset.limit(per_page).offset(offset).all
  
    [orders, total]
  end
  def handle_filtered_orders(user, status, page = 1)
    per_page = 3
    orders, total_orders = filter_orders_by_status(status, page, per_page)
  
    if orders.empty?
      @bot.api.send_message(chat_id: user[:telegram_id], text: "#{Translator.t(user.language || 'pl', 'no_orders_with_status')} #{status_text(status, user)}.")
      return
    end
  
    orders.each do |order|
      # Тут використовуємо готову build_order_summary (можна без запитів бо вже маємо все)
      summary = <<~MSG
        #{Translator.t(user.language, 'order_label')} ##{order[:id]}
        👤 #{order[:first_name]} #{order[:last_name]} (#{order[:username]})
        📞 #{order[:phone]}
        🏠 #{order[:address]}
        📅 #{order[:created_at].strftime('%Y-%m-%d %H:%M')}
        #{Translator.t(user.language, 'status')} #{status_text(order[:status], user)}
      MSG
  
      kb = []
  
      # Залежно від статусу — різні кнопки зміни статусу
      case order[:status]
      when 'pending'
        kb << [Telegram::Bot::Types::InlineKeyboardButton.new(text: Translator.t(user.language || 'pl', 'confirm'), callback_data: "confirm_order:#{order[:id]}")]
        kb << [Telegram::Bot::Types::InlineKeyboardButton.new(text: Translator.t(user.language || 'pl', 'cancel'), callback_data: "cancel_order:#{order[:id]}")]
      when 'confirmed'
        kb << [Telegram::Bot::Types::InlineKeyboardButton.new(text: Translator.t(user.language || 'pl', 'mark_shipped'), callback_data: "send_order:#{order[:id]}")]
      end
  
      kb << [Telegram::Bot::Types::InlineKeyboardButton.new(text: Translator.t(user.language || 'pl', 'details'), callback_data: "order_details:#{order[:id]}")]
  
      markup = Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: kb)
      @bot.api.send_message(chat_id: user[:telegram_id], text: summary.strip, reply_markup: markup)
    end
  
    # Пагінація
    buttons = []
    buttons << Telegram::Bot::Types::InlineKeyboardButton.new(text: Translator.t(user.language || 'pl', 'previous'), callback_data: "filter_#{status}_page:#{page - 1}") if page > 1
    if total_orders > page * per_page
      buttons << Telegram::Bot::Types::InlineKeyboardButton.new(text: Translator.t(user.language || 'pl', 'next'), callback_data: "filter_#{status}_page:#{page + 1}")
    end
  
    unless buttons.empty?
      markup = Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: [buttons])
      @bot.api.send_message(chat_id: user[:telegram_id], text: "#{Translator.t(user.language || 'pl', 'page')} #{page} — #{Translator.t(user.language || 'pl', 'status')} #{status_text(status, user)}", reply_markup: markup)
    end
  end
  def confirm_order(order_id, admin)
    updated = DB[:orders].where(id: order_id, status: 'pending').update(status: 'confirmed', updated_at: Time.now)
    
    
    if updated > 0
      @bot.api.send_message(chat_id: admin['id'], text: Translator.t(admin['language_code'] || 'pl', 'order_confirmed_admin') % { id: order_id })
      order = DB[:orders].where(id: order_id).first
      user = DB[:users].where(id: order[:user_id]).first
      @bot.api.send_message(chat_id: user[:telegram_id], text: Translator.t(user[:language] || 'pl', 'order_confirmed_user') % { id: order_id })
    else
      @bot.api.send_message(chat_id: admin['id'], text: Translator.t(admin['language_code'] || 'pl', 'confirm_error'))
    end
  end 
  def cancel_order(order_id, admin)
    updated = DB[:orders].where(id: order_id, status: 'pending').update(status: 'cancelled', updated_at: Time.now)
  
    if updated > 0
      @bot.api.send_message(chat_id: admin['id'], text: Translator.t(admin['language_code'] || 'pl', 'order_cancelled_admin') % { id: order_id }) 
      order = DB[:orders].where(id: order_id).first
      user = DB[:users].where(id: order[:user_id]).first
      @bot.api.send_message(chat_id: user[:telegram_id], text: Translator.t(user[:language]  || 'pl', 'order_cancelled_user') % { id: order_id })
    else
      @bot.api.send_message(chat_id: admin['id'], text: Translator.t(admin['language_code'] || 'pl', 'cancel_error'))
    end

  end
  def send_order(order_id, admin)
    updated = DB[:orders].where(id: order_id, status: 'confirmed').update(status: 'sent', updated_at: Time.now)
  
    if updated > 0
      @bot.api.send_message(chat_id: admin['id'], text: Translator.t(admin['language_code'] || 'pl', 'order_shipped_admin') % { id: order_id })
      order = DB[:orders].where(id: order_id).first
      user = DB[:users].where(id: order[:user_id]).first
      @bot.api.send_message(chat_id: user[:telegram_id], text: Translator.t(user[:language]  || 'pl', 'order_shipped_user') % { id: order_id })
    else
      @bot.api.send_message(chat_id: admin['id'], text: Translator.t(admin['language_code'] || 'pl', 'ship_error'))
    end
    
    
  end
end
