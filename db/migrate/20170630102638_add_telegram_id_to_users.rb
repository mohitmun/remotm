class AddTelegramIdToUsers < ActiveRecord::Migration[5.1]
  def change
    add_column :users, :telegram_id, :text
  end
end
