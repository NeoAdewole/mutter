class MainController < ApplicationController
  def index
    @live_streams = home_page_streams
  end

  private

  # Admins can switch home page streams off, or lower how many are shown (Admin > Settings).
  def home_page_streams
    return [] unless SiteSetting.get('homepage_streams_enabled')

    Twitch::LiveStreams.current(limit: SiteSetting.get('homepage_streams_limit'))
  end
end
