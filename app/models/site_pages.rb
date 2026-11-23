# Home, About and the four section landing pages, as editable Pages.
#
# They are created on first use (and by db/seeds.rb) with the content the site
# had before it could be edited, so nothing changes until an admin edits them.
# Creation is idempotent and never overwrites a page that already exists.
#
#   SitePages.page('home')   # => the Home page (created if missing)
#   SitePages.all            # => every site page, Home first
module SitePages
  # Landing pages first: the Home page's cards feature them.
  CREATION_ORDER = (Section.keys + %w[about home]).freeze
  DISPLAY_ORDER = (%w[home about] + Section.keys).freeze

  ABOUT_TEXT = <<~MARKDOWN.freeze
    ## The Idea

    An idea you have muttered under your breath is just that. The same idea uttered by a collective can take form and become something more. A collective voice.
  MARKDOWN

  INFO_TEXT = <<~MARKDOWN.freeze
    We are building a digital community for creatives to collaborate and create tools and solutions that help you do what you better.

    Join us today and be part of the journey to create a space that:

    - Empowers creators
    - Fosters collaboration
    - Encourages innovation
    - Builds lasting connections
  MARKDOWN

  # Cards on the Home page: the picture and button wording; the title and text come from the landing page.
  HOME_CARDS = {
    'streaming' => { image: 'https://picsum.photos/id/435/928/548', alt: 'Camera' },
    'content' => { image: 'https://picsum.photos/id/403/928/548', alt: 'Typewriter' },
    'gaming' => { image: 'https://picsum.photos/id/96/928/548', alt: 'Game Controller' },
    'community' => { image: 'https://picsum.photos/id/672/928/548', alt: 'Floor shot showing feet and shoes of passengers in a bus' }
  }.freeze

  module_function

  def page(key)
    Page.find_by(system_key: key.to_s) || begin
      ensure!
      Page.find_by!(system_key: key.to_s)
    end
  end

  def all
    ensure!
    by_key = Page.site_pages.index_by(&:system_key)
    DISPLAY_ORDER.filter_map { |key| by_key[key] }
  end

  def ensure!
    missing = CREATION_ORDER.reject { |key| Page.exists?(system_key: key) }
    return if missing.empty?

    Page.transaction { missing.each { |key| create_default(key) } }
  rescue ActiveRecord::RecordNotUnique
    nil # another request created them first
  end

  def create_default(key)
    case key
    when 'home' then create_home
    when 'about' then Page.create!(system_key: 'about', title: 'About Us', body: ABOUT_TEXT)
    else
      section = Section.find(key)
      Page.create!(system_key: key, title: section.title, body: section.blurb)
    end
  end

  def create_home
    home = Page.create!(system_key: 'home', title: 'Home', body: '', show_title: false)
    carousel = home.blocks.create!(kind: 'carousel', show_live_streams: true)
    (1..4).each do |n|
      carousel.items.create!(image_url: "https://picsum.photos/1500/500?text=Banner+#{n}", alt_text: "Banner #{n}")
    end
    create_home_cards(home)
    home.blocks.create!(kind: 'text', body: INFO_TEXT)
  end

  def create_home_cards(home)
    row = home.blocks.create!(kind: 'cards', columns: 4)
    HOME_CARDS.each do |key, card|
      row.items.create!(featured_page: Page.find_by!(system_key: key), image_url: card[:image], alt_text: card[:alt],
                        link_label: "Explore #{Section.find(key).title}")
    end
  end

  private_class_method :create_default, :create_home, :create_home_cards
end
