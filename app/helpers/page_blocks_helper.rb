module PageBlocksHelper
  # Full class names on purpose: Tailwind finds classes by scanning for them, so
  # they cannot be built up from pieces. Fewer columns on narrower screens.
  GRID_COLUMNS = {
    1 => 'grid-cols-1',
    2 => 'grid-cols-1 tablet:grid-cols-2',
    3 => 'grid-cols-1 tablet:grid-cols-2 laptop:grid-cols-3',
    4 => 'grid-cols-1 tablet:grid-cols-2 laptop:grid-cols-4',
    5 => 'grid-cols-1 tablet:grid-cols-2 laptop:grid-cols-3 desktop:grid-cols-5',
    6 => 'grid-cols-1 tablet:grid-cols-2 laptop:grid-cols-3 desktop:grid-cols-6'
  }.freeze

  def card_grid_classes(columns)
    GRID_COLUMNS.fetch(columns, GRID_COLUMNS.fetch(3))
  end

  # The page's blocks in order, with their slides / cards (and the pages cards feature) loaded together.
  def blocks_for(page)
    page.blocks.includes(items: :featured_page)
  end

  # The cards of a row this visitor may see.
  def visible_cards(block)
    block.items.select { |card| card.visible_to?(admin_signed_in?) }
  end

  def carousel_slides(block)
    block.items.map { |slide| { src: slide.image_url, alt: slide.alt_text, href: slide.link_url.presence } }
  end

  # Live Twitch streams for a carousel that wants them, subject to the admin's
  # Settings. Looked up at most once per request, however many carousels there are.
  def carousel_streams(block)
    return [] unless block.show_live_streams? && SiteSetting.get('homepage_streams_enabled')

    @carousel_streams ||= Twitch::LiveStreams.current(limit: SiteSetting.get('homepage_streams_limit'))
  end
end
