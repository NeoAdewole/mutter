module Twitch
  # A channel that is live right now.
  Stream = Struct.new(:login, :name, :title, :game, :viewers, keyword_init: true)
end
