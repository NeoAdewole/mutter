# The four fixed top-level areas of the site. They are not database rows:
# they are the skeleton that pages hang from, so they stay in code (and in the
# navbar) even when no page has been written yet.
class Section
  attr_reader :key, :title, :blurb

  def initialize(key:, title:, blurb:)
    @key = key
    @title = title
    @blurb = blurb
  end

  ALL = [
    new(key: 'streaming', title: 'Streaming',
        blurb: 'Whether IRL, music or gaming, get the tools you need to keep chat engaged and manage your stream.'),
    new(key: 'content', title: 'Content',
        blurb: 'Whatever level you are in your content creation journey, get resources to push you to the next stage.'),
    new(key: 'gaming', title: 'Gaming',
        blurb: 'Guides, news and ideas for the games you play and the ones you stream.'),
    new(key: 'community', title: 'Community',
        blurb: 'Meet other creatives, collaborate and build lasting connections.')
  ].freeze

  # Features that existed before the CMS and are not stored as pages. They
  # appear first in their section's menu and landing page. `route` names a
  # route helper; both are login-gated by their own controllers.
  BuiltIn = Struct.new(:label, :route)
  BUILT_INS = {
    'streaming' => [BuiltIn.new('Live chat', :live_chat_path)],
    'community' => [BuiltIn.new('Twitter Accounts', :twitter_accounts_path), BuiltIn.new('Tweets', :tweets_path)]
  }.freeze

  def self.all
    ALL
  end

  def built_ins
    BUILT_INS.fetch(key, [])
  end

  def self.keys
    ALL.map(&:key)
  end

  def self.find(key)
    ALL.find { |section| section.key == key.to_s }
  end

  def path
    "/#{key}"
  end

  def to_param
    key
  end
end
