class AddShowStreamOnHomepageToUsers < ActiveRecord::Migration[7.2]
  def change
    # Opt-out: users with a connected Twitch channel can be featured on the
    # home page while live unless they turn this off.
    add_column :users, :show_stream_on_homepage, :boolean, null: false, default: true
  end
end
