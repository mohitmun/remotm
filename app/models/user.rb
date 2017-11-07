require 'telegram/bot'
class User < ActiveRecord::Base
  store_accessor :json_store, :profile_pic, :state, :lang, :latlong, :delivery, :delivery_distance, :display_name, :phone, :upi, :provide_cash,
   :sso_details, :auth, :wallet_from, :type_of_business, :car_details, :car_no, :house_images, :profession, :house_details, :email, :telegram_username, :current_bot
  has_many :orders

  def self.create_from_message(message)
    user = User.create(fb_id: message.sender['id'], state: "state_ask_for_lang")
    user.save_fb_profile
    # user.send_welcome_message(message)
    user.send_select_language(message)
  end

  def self.create_from_message_telegram(chat_id, hash_params)
    user = User.create(telegram_id: chat_id, state: "state_ask_for_lang")
    user.first_name = hash_params.message.from.first_name
    user.last_name = hash_params.message.from.last_name
    user.current_bot = "telegram"
    # user.send_welcome_message(message)
    user.send_select_language
    user.save
  end

  INCOMING_TELEGRAM_URL = "https://ee928257.ngrok.io/incoming_telegram"
  def self.create_webhook
    cmd = "curl -X GET '#{TELEGRAM_URL}setWebhook?url=#{INCOMING_TELEGRAM_URL}'"
    puts cmd
    res = `#{cmd}`
  end

  TELEGRAM_URL = "https://api.telegram.org/bot#{ENV["TELEGRAM_TOKEN"]}/"

  def self.find_by_email(email)
    User.where("(json_store ->> 'email') = ?", email).last
  end

  after_initialize :init

  def init
    self.latlong = [0,0] if latlong.blank?
    @telegram_client = Telegram::Bot::Client.new(ENV["TELEGRAM_TOKEN"])
  end

  def send_telegram_buttons(chat_id)
    @telegram_client.send_message chat_id: chat_id, text: 'Test', reply_markup: {inline_keyboard: [[{text: "Chus", url: "http://google.com"}]]}
  end

  def self.curl(s)
    puts "============"
    puts "curl #{s}"
    res = `curl #{s} -H 'content-type: application/json'`
    puts "============"
    puts res
    puts "============"
    return res
  end


  def delivery?
    !!delivery
  end

  def send_select_language(message = nil)
    buttons = {"set_english" => I18n.t('english'),  "set_hindi" => I18n.t('hindi')}
    send_buttons(nil, I18n.t('select_language'), buttons)
  end

  def get_fb_profile
    res = `curl https://graph.facebook.com/v2.6/#{fb_id}?access_token=#{ENV['ACCESS_TOKEN']}`
    json_res = JSON.parse(res)
    return json_res
  end


  # [
  #       {
  #         "title": "Chus title",
  #         "subtitle": "Chus subtitle",
  #         "buttons": [
  #           {
  #             "title": "View",
  #             "type": "postback",
  #             "payload": "chussandas"
  #           }
  #         ]
  #       },{
  #         "title": "Chus title1",
  #         "subtitle": "Chus subtitle1",
          
  #         "buttons": [
  #           {
  #             "title": "View",
  #             "type": "postback",
  #             "payload": "chussandas"
  #           }
  #         ]
  #       }
  #     ]
  
  # buttons
  # [
  #       {
  #         "title": "View More",
  #         "type": "postback",
  #         "payload": "payload"
  #       }
  #     ]
  def self.create_group(count)
    group = []
    while count != 0
      if count%4 == 0
        group << 4
        count = count - 4
      elsif count%4 == 1
        group << 2
        group << 3
        count = count - 5
      else
        group << count%4
        count = count - (count%4)
      end
    end
    return group.reverse
  end

  def self.send_list(message, elements, buttons)
    
    if elements.count == 1
      elements[0][:buttons] += buttons if !buttons.blank?
      send_message(
      "attachment": 
      {
        "type": "template",
        "payload": {
          "template_type": "generic",
          "elements": elements
        }
      })
      return 
    end
    i = 0
    group = User.create_group(elements.count)
    group.each_with_index do |count, index|
      j = i + count
      if index != (group.count - 1)
        buttons_ = []
      else
        buttons_ = buttons
      end
      send_message(
      "attachment": 
      {
        "type": "template",
        "payload": {
          "template_type": "list",
          "top_element_style": "compact",
          "elements": elements[i..j-1],
          "buttons": buttons_
        }
      })
      i = j
    end
  end
def send_list(elements, buttons)
    
    if elements.count == 1
      elements[0][:buttons] += buttons if !buttons.blank?
      send_message(
      "attachment": 
      {
        "type": "template",
        "payload": {
          "template_type": "generic",
          "elements": elements
        }
      })
      return 
    end
    i = 0
    group = User.create_group(elements.count)
    group.each_with_index do |count, index|
      j = i + count
      if index != (group.count - 1)
        buttons_ = []
      else
        buttons_ = buttons
      end
      send_message(
      {"attachment": 
            {
              "type": "template",
              "payload": {
                "template_type": "list",
                "top_element_style": "compact",
                "elements": elements[i..j-1],
                "buttons": buttons_
              }
            }}, false, true)
      i = j
    end
  end

  def save_fb_profile
    res = get_fb_profile
    self.first_name = res["first_name"]
    self.last_name = res["last_name"]
    self.profile_pic = res["profile_pic"]
    self.save
  end

  def send_buttons(message, text, buttons_hash)
    buttons = []
    buttons_hash.each do |k,v|
      buttons << {type: 'postback', title: v, payload: k}
    end
    send_message(
      {attachment: {
             type: 'template',
              payload: {
                template_type: 'button',
                text: text,
                buttons: buttons
              }
            }}, true
    )
  end

  def send_welcome_message(message)
    buttons = {"link_upi" => I18n.t('link_upi')}
    send_buttons(message, I18n.t('hello', name: first_name), buttons)
  end


  def get_currency(currency_id)
    # CURRENCY.
    # {"id"=>1, "cur_country"=>"United Arab Emirates", "cur_currency"=>"United Arab Emirates Dirham", "cur_code"=>"AED", "cur_symbol"=>"", "cur_thousand_separator"=>nil, "cur_decimal_separator"=>nil, "cur_country_iso_2"=>"AE", "cur_country_iso_3"=>"ARE", "cur_weight"=>"1.00", "cur_active"=>1, "created_at"=>"2017-06-10 21:50:15", "updated_at"=>"2017-06-10 21:50:15", "deleted_at"=>nil}
    res = nil
    CURRENCY.each do |currency_hash|
      if currency_id == currency_hash.id
        return currency_hash
      end
    end
    return res

  end

  def send_generic(elements)
    puts elements
    this_times = (elements.count/10.0).ceil
    this_times.times do |i|
      send_message(
        "attachment": 
        {
          "type": "template",
          "payload": {
            "template_type": "generic",
            "elements": elements[i*10..(i*10)+9]
          }
        })
    end
  end

  SSO_URL = "https://v1-sso-api.digitaltown.com/oauth/authorize?client_id=#{ENV['DT_CLIENT_ID']}&redirect_uri=https://#{ENV['HOST']}/incoming_digitaltown&response_type=code&scope=email"
  # STATE = {0 => "ask_for_role", 1 => "ask_for_business", 2 => "ask_for_location", }
  # STATES = [ask_for_lang, ask_for_role, send_welcome_message, ask_for_business, ]
  def on_postback(postback)
    payload = postback.payload
    message = postback
    if payload == "link_upi"
      update_attributes(role: "business", state: "state_get_upi")
      send_message(text: I18n.t('please_send_upi_address'))
    elsif payload == "more_settings"
      send_more_settings(message)
    elsif payload == "GET_STARTED_PAYLOAD"
      send_select_language(message)
    elsif payload == "view_wallets"
      send_wallets
    elsif payload == "set_hindi"
      update_attributes(lang: "hi", state: "state_send_welcome_message")
      send_welcome_message(message)
    elsif payload == "set_english"
      update_attributes(lang: "en", state: "state_send_welcome_message")
      send_welcome_message(message)
    elsif payload == "update_location"
      ask_for_location(postback)  
    elsif payload == "disable_delivery"
      update_attribute(:delivery, false)
      send_message(text: I18n.t('disable_delivery_success'))
    elsif payload == "update_name"
      send_message(text: I18n.t('update_name'))
      update_attributes(state: "state_get_name")
    elsif payload.include?("give_cash")
      order_id = payload.split(":")[1].to_i
      update_attributes(state: "accept_order_on_location_update:#{order_id}")
      ask_for_location
    elsif payload.include?("do_not_give_cash")
      send_message(text: I18n.t("we_will_notify_you_in_future_for_more"))
    elsif payload.include?("received_money")
      order_id = payload.split(":")[1].to_i
      order = Order.find(order_id)
      order.place
    elsif payload == "update_phone"
      send_message(text: I18n.t('update_phone'))
      update_attributes(state: "state_get_phone")
    elsif payload.include?("view_order")
      Order.view_order(message)
    elsif payload.include?("set_delivery_distance")
      distance = payload.split(":").last
      update_attribute(:delivery_distance, distance)
      send_message(text: I18n.t('delivery_distance_success', distance: distance))
    end
  end

  def name
    return "#{first_name} #{last_name}"
  end

  def send_delivery_success(message)
    delivery_distances = I18n.t('delivery_distances')
    quick_replies = []
    delivery_distances.each do |item|
      quick_replies << {
        content_type: 'text',
        title: item,
        payload: "set_delivery_distance:#{item}"
      }
    end
    quick_replies << {
      content_type: 'text',
      title: "Anywhere in city",
      payload: "set_delivery_distance:any"
    }
    send_message(text: I18n.t('enable_delivery_success'))
    send_message(
        text: I18n.t('select_delivery_distance'),
        quick_replies: quick_replies
      )
  end

  def send_message(message, buttons = false, list = false)
    if current_bot.blank? || current_bot == "fb"
      payload = {
              recipient: {id: fb_id},
              message: message
      }
      Facebook::Messenger::Bot.deliver(payload, access_token: ENV['ACCESS_TOKEN'])
    else
      text = message.text rescue nil
      # #todo
      # hanlde quick reply
      if !text.blank?
        # quick_replies = message.
        @telegram_client.send_message chat_id: telegram_id, text: text
        quick_replies = message.quick_replies rescue nil
        if !quick_replies.blank?
          tele_buttons = []
          quick_replies.each do |qr|
            title = qr.title rescue nil
            payload = qr.payload rescue nil
            if !title.blank?
              tele_buttons << {
                text: title,
                callback_data: payload
              }
            end
          end
          @telegram_client.send_message chat_id: telegram_id, text: ".", reply_markup: {inline_keyboard: [tele_buttons]} if !tele_buttons.blank?
        end
      elsif buttons
        text = message.attachment.payload.text rescue ""
        buttons = message.attachment.payload.buttons rescue []
        tele_buttons = []
        buttons.each do |b|
          b_hash = { text: b.title}
          payload = b.payload rescue nil
          if payload
            b_hash[:callback_data] = b.payload
          end
          url = b.url rescue nil
          if url
            b_hash[:url] = url
          end
          tele_buttons << b_hash
        end
        @telegram_client.send_message chat_id: telegram_id, text: text, reply_markup: {inline_keyboard: [tele_buttons]}
      elsif list
        # {"attachment": 
        #     {
        #       "type": "template",
        #       "payload": {
        #         "template_type": "list",
        #         "top_element_style": "compact",
        #         "elements": elements[i..j-1],
        #         "buttons": buttons_
        #       }
        #     }}, false, true)
        tele_buttons = []
        message.attachment.payload.elements.each do |ele|
          tele_buttons = [[{
            text: "Select",
            callback_data: ele.buttons.last.payload
          }]]
          @telegram_client.send_message chat_id: telegram_id, text: ele.title + "\n" + ele.subtitle, reply_markup: {inline_keyboard: tele_buttons}
        end
      else
        # send_message(
        # "attachment": 
        # {
        #   "type": "template",
        #   "payload": {
        #     "template_type": "generic",
        #     "elements": elements[i*10..(i*10)+9]
        #   }
        # })
        generic = message.attachment.payload.template_type rescue nil
        if generic == "generic"
          message.attachment.payload.elements.each do |ele|
            tele_buttons = []
            ele.buttons.each do |b|
              tele_buttons << [{
                text: b.title,
                callback_data: b.payload
              }]
            end
            @telegram_client.send_message chat_id: telegram_id, text: ele.title + "\n" + ele.subtitle, reply_markup: {inline_keyboard: tele_buttons}
          end
        end
      end
        # @telegram_client.send_message chat_id: telegram_id, text: ele.title + "\n" + ele.subtitle, reply_markup: {inline_keyboard: tele_buttons}
        # "view wallets"
        # "show transactions"
        # "update location"
        # "change role"
        # "more settings"
    end
  end

  def send_more_settings(message)
    if role == "business"
      delivery_key = self.delivery ? "disable_delivery" : "enable_delivery"
      send_buttons(message, I18n.t("more_settings"), 
        { 
          "update_name" => I18n.t("update_name_menu"),
          "update_phone" => I18n.t("update_phone_menu")
          # "update_grocery" => I18n.t("update_grocery"),
        }
      )
      send_buttons(message, "more options..", 
        { 
          delivery_key => I18n.t(delivery_key)
        }
      )
    else
      send_buttons(message, I18n.t("more_settings"), 
        { 
          "new_order" => I18n.t("new_order"),
          "view_past_orders" => I18n.t("view_past_orders")
        }
      )
    end
  end

  def handle_quick_replies(message)
    payload = message.quick_reply
    if payload.include?("set_delivery_distance")
      distance = payload.split(":").last
      update_attribute(:delivery_distance, distance)
      send_message(text: I18n.t('delivery_distance_success', distance: distance))
    elsif payload.include?("provide_cash")
      update_attributes(provide_cash: !payload.include?("do_not"))
    elsif payload.include?("place_order")
      order_id = payload.split(":").last
      order = Order.find(order_id)
      order.place(message)
    elsif payload.include?("money_from")
      to = payload.split(":")[-2]
      from = payload.split(":")[-3]
      amount = payload.split(":")[-1]
      User.send_money(from, to, amount)
    elsif payload.include?("declined_money")
      user_id = payload.split(":").last
      user = User.find user_id
      user.send_message(text: "#{name} declined transaction")
    end
  end

  def business?
    role == "business"
  end

  def start_flow(message)
    if !message.location_coordinates.blank?
      send_message(text: I18n.t("location_updated"))
      update_attribute(:latlong, message.location_coordinates)
      # send_message(text: I18n.t("enter_search"))
      if state.include?("accept_order_on_location_update")
        order_id = state.split(":")[1]
        order = Order.find(order_id)
        order.mark_accepted(self.id)
      elsif  state.include?("ask_for_location_after_amount")
        order_id = state.split(":")[1]
      
        count = find_nearby_giver(order_id)
        send_message(text: I18n.t("looking_for_nearby_donor", count: count))
      end
      return
    end
    if !message.quick_reply.blank?
      handle_quick_replies(message)
      puts "wo"
      return
    end
    if message.text.to_s.downcase.include?("update location")
      ask_for_location
      return
    end
    if message.text.to_s.downcase.include?("change role")
      send_welcome_message
      return
    end
    if message.text.to_s.downcase.include?("more settings")
      send_more_settings
      return
    end
    if message.text.to_s.downcase.include?("view wallets")
      send_wallets
      return
    end
    if message.text.to_s.downcase.include?("send money")
      send_message(text: "Sending your current wallets")
      send_wallets
      send_message(text: "Please enter email address of user you want to sent money to and amuont space seperated\nExample: example@abc.com 10")
      update_attributes(state: "state_send_money")
      return
    end
    if message.text.to_s.downcase.include?("receive money")
      send_message(text: "Sending your current wallets")
      send_wallets
      send_message(text: "Please enter email address of user you want to receive money from and amuont space seperated\nExample: example@abc.com 10")
      update_attributes(state: "state_receive_money")
      return
    end
    if self.state.blank?
      self.state = "state_ask_for_lang"
    end
    case self.state
    when "state_ask_for_lang"
      send_select_language(message)
    when "state_send_welcome_message"
      send_welcome_message(message)
    when "state_get_upi"
      update_attributes(upi: message.text, state: "state_get_amount")
      send_message(text: I18n.t("upi_address_saved"))
    when "state_get_amount"
      if message.text.to_i > 0
        order = orders.create(amount: message.text.to_i)
        update_attributes(state: "ask_for_location_after_amount:#{order.id}")
        ask_for_location
      else
        send_message(text: I18n.t("please_enter_valid_amount"))
      end
    when "state_send_money"
      email,amount = message.text.split(" ") rescue [nil,nil]
      if !email.blank? && !amount.blank?
        user = User.find_by_email(email) rescue nil
        if user.blank?
          send_message(text: "User not found")
        else
          User.send_money(self.id, user.id, amount)
        end
      end
      state_done
    when "state_receive_money"
      email,amount = message.text.split(" ") rescue [nil,nil]
      if !email.blank? && !amount.blank?
        user = User.find_by_email(email)
        user.send_message(text: "#{name} is requesting #{amount} money from you. Do you want to continue?", quick_replies: [
        {
          title: I18n.t("yes"),
          content_type: "text",
          payload: "money_from:#{user.id}:#{self.id}:#{amount}"
        },{
          title: I18n.t("no"),
          content_type: "text",
          payload: "declined_money:#{self.id}"
        }
      ])
      end
      state_done
    when "state_get_name"
      update_attributes(display_name: message.text, state: "state_done")
      send_message(text: I18n.t("update_name_success", name: message.text))
    when "state_get_phone"
      update_attributes(phone: message.text, state: "state_done")
      send_message(text: I18n.t("update_phone_success", phone: message.text))
    when "state_done"
      after_onboarding(message)
    when "state_get_transfer_details"
      to_id, amount = message.text.split(" ")
      wallet_transfer(wallet_from, to_id, amount)
      send_message(text: "Money transferred!")
      update_attributes(state: "state_done")
      send_wallets
    when "state_ask_for_order"
      # query = message.text
      if message.text.size > 2
        send_message(text: I18n.t("searching_for", query: message.text))
        Grocery.send_items(message, self)
      else
        send_message(text: I18n.t("enter_minimum_3", query: message.text))
      end
      update_attributes(state: "state_done")
    else
       if message.text.to_i > 0
        order = orders.create(amount: message.text.to_i)
        update_attributes(state: "ask_for_location_after_amount:#{order.id}")
        ask_for_location
      else
        send_message(text: I18n.t("please_enter_valid_amount"))
      end
      # send_welcome_message(message)
    end
  end

  def self.cal_distance(loc1, loc2)
    rad_per_deg = Math::PI/180  # PI / 180
    rkm = 6371                # Earth radius in kilometers
    rm = rkm * 1000             # Radius in meters

    dlat_rad = (loc2[0]-loc1[0]) * rad_per_deg  # Delta, converted to rad
    dlon_rad = (loc2[1]-loc1[1]) * rad_per_deg

    lat1_rad, lon1_rad = loc1.map {|i| i * rad_per_deg }
    lat2_rad, lon2_rad = loc2.map {|i| i * rad_per_deg }

    a = Math.sin(dlat_rad/2)**2 + Math.cos(lat1_rad) * Math.cos(lat2_rad) * Math.sin(dlon_rad/2)**2
    c = 2 * Math::atan2(Math::sqrt(a), Math::sqrt(1-a))

    rm * c/1000.0 # Delta in meters
  end


  def state_done
    update_attributes(state: "state_done")
  end


  def after_onboarding(message)
    # send_message(text: "Onboarded")
    # send_more_settings(message)
    Business.ask_for_business(self)
  end

  def self.send_money(from, to, amount)
    from_user = User.find(from)
    to_user = User.find(to)
    from_walllet_id = from_user.get_wallets.result.last.data.last.wallet_id
    to_walllet_id = to_user.get_wallets.result.last.data.last.wallet_id
    from_user.wallet_transfer(from_walllet_id, to_walllet_id, amount)
    from_user.send_message(text: "Transaction complete! You have sent #{amount} to #{to_user.name}")
    to_user.send_message(text: "Transaction complete! You have received #{amount} from #{from_user.name}")
    from_user.send_wallets
    to_user.send_wallets
  end

  def find_nearby_giver(order_id)
    # get current latlong
    # search in db nearby 2 kms
    # send message to all with yes/no button
    # if yes send back this guy, we have donor !!! 
    count = 0
    User.where.not(id: self.id).each do |user|
      dis = User.cal_distance(latlong, user.latlong)
      if dis < 2
        count = count + 1
        user.send_buttons(nil, I18n.t("do_you_have_cash", name: name, distance: dis, amount: Order.find(order_id).amount), {
            "give_cash:#{order_id}" => I18n.t("give_cash"),
            "do_not_give_cash:#{order_id}" => I18n.t("do_not_give_cash")
          })
      end
    end
    return count
  end

  def send_generic(elements)
    this_times = (elements.count/10.0).ceil
    this_times.times do |i|
      send_message(
        "attachment": 
        {
          "type": "template",
          "payload": {
            "template_type": "generic",
            "elements": elements[i*10..(i*10)+9]
          }
        })
    end
  end

  def ask_for_location(message = nil)
    please_share_location_msg = I18n.t("please_share_your_location")
    if current_bot.blank? || current_bot == "fb"
      send_message("text": please_share_location_msg,
          "quick_replies":[
            {
              "content_type": "location",
            }
          ])
    else
      cmd = "curl -X GET -H 'Accept-Encoding: gzip, deflate' -H 'Accept: */*' -H 'Connection: keep-alive' -H 'User-Agent: python-requests/2.12.3' -d '' '#{TELEGRAM_URL}sendMessage?text=#{please_share_location_msg.gsub(" ", "+")}&chat_id=#{self.telegram_id}&reply_markup=%7B%22resize_keyboard%22%3A+false%2C+%22one_time_keyboard%22%3A+true%2C+%22keyboard%22%3A+%5B%5B%7B%22text%22%3A+%22Location%22%2C+%22request_location%22%3A+true%7D%5D%5D%7D'"
      puts cmd
      `#{cmd}`
    end
  end

end
