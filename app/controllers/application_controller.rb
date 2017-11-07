class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  before_action :permit_all

  def incoming_telegram
    hash_params = params.to_h
    Rails.cache.write("tchus", hash_params)
    chat_id = hash_params.message.chat.id rescue hash_params.callback_query.message.chat.id
    text = hash_params.message.text rescue nil
    payload = hash_params.callback_query.data rescue nil
    telegram_location = hash_params.message.location rescue nil
    user = User.find_by(telegram_id: chat_id) rescue nil
    if user.blank?
      User.create_from_message_telegram(chat_id, hash_params)
    elsif payload.blank?
      user.current_bot = "telegram"
      user.save
      location_coordinates = [telegram_location.latitude, telegram_location.longitude] rescue {}
      puts "===="
      puts "location_coordinates: #{location_coordinates} telegram_location: #{telegram_location}"
      puts "===="
      tmp = {text: text, location_coordinates: location_coordinates, quick_reply: {}}
      user.start_flow(tmp)
    else
      user.current_bot = "telegram"
      user.save
      user.on_postback({payload: payload})
    end
    render json: {success: true}
  end

  def permit_all
    params.permit!  
  end

end
