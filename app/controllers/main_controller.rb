class MainController < ApplicationController
  def index
    @live_streams = Twitch::LiveStreams.current
  end
end
