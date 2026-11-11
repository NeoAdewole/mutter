module Youtube
  # A person's own YouTube channel. handle is their @handle without the "@".
  Channel = Struct.new(:id, :title, :handle, keyword_init: true)
end
