class Order < ApplicationRecord
  store_accessor :json_store, :item_ids, :lender_id, :amount, :status
  after_initialize :init
  belongs_to :user

  def init
    self.item_ids = [] if self.item_ids.blank?
  end

  def lender
    return User.find(lender_id)
  end

  def mark_accepted(lender_id)
    update_attributes(status: "accepted", lender_id: lender_id)
    user.send_buttons(nil, I18n.t("order_accepted", name: lender.name), {
      "received_money:#{self.id}" => I18n.t("received_money"),
      "order_cancel:#{self.id}" => I18n.t("order_cancel")
    })
    request_payment
  end

  def request_payment
    key_id = "rzp_live_ILgsfZCZoFIKMb"
    upi_address = user.upi
    response = `curl 'https://api.razorpay.com/v1/payments/create/ajax' --data 'contact=9821388933&email=mohitcrox%40gmail.com&method=upi&vpa=#{upi_address}&amount=#{amount*100}&currency=INR&description=remotem&key_id=#{key_id}&_[checkout_id]=8xSum4wr0SPSt7&_[referer]=https%3A%2F%2Frazorpay.com%2Fdemo%2F&_[library]=checkoutjs&_[platform]=browser' --compressed`
    puts "response: #{response}"
    url = response.parse_json.request.url
    delay.check_payment(url)
    return response
  end

  def check_payment(url)
    10.times do |i|
      res = `curl #{url}`
      puts "======"
      puts "check_payment: #{res}"
      puts "======"
      status = res.parse_json.status rescue nil
      if status == "created"
        puts "Payment pending"
      else
        puts "Payment received"
        user.send_message(text: I18n.t("we_have_received_amount_from_you", amount: amount))
        send_directions
        return
      end
      sleep(8)
    end
  end

  def send_directions
    buttons = []
    buttons << {
      title: I18n.t("get_directions"),
      type: "web_url",
      url: "http://maps.google.com/maps?saddr=#{user.latlong.join(",")}&daddr=#{lender.latlong.join(",")}"
    }
    message = {
      "attachment": 
        {
          "type": "template",
          "payload": {
            "template_type": "button",
            "text": I18n.t("directions", name: lender.name),
            "buttons": buttons
          }
      }
    }
    user.send_message(message)
  end

  def place
    # trasnfer money to lender
    lender.send_message(text: "You have received Rs.#{amount} in your bank account linked with UPI address #{lender.upi}")
  end


end
