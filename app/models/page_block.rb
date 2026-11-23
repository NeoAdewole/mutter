# One building block of a page, shown in order beneath the page's main text.
#
#   carousel  a rotating banner of slides (optionally with live Twitch streams first)
#   cards     a row of cards in 1-6 columns; a card can feature an existing page
#   text      a stretch of Markdown, with an optional heading
#
# Carousels and card rows own ordered BlockItems (their slides / cards). Only
# the settings that belong to a block's kind are used (see PERMITTED).
class PageBlock < ApplicationRecord
  KINDS = {
    'carousel' => { label: 'Carousel', item: 'slide',
                    help: 'Rotating banner images, optionally with live streams from members first.' },
    'cards' => { label: 'Card row', item: 'card',
                 help: 'A row of cards in the number of columns you choose. A card can feature one of your pages.' },
    'text' => { label: 'Text', item: nil,
                help: 'A stretch of text with an optional heading.' }
  }.freeze
  # The form fields each kind may set.
  PERMITTED = { 'carousel' => %i[show_live_streams], 'cards' => %i[heading columns], 'text' => %i[heading body] }.freeze
  COLUMNS = (1..6)
  MAX_PER_PAGE = 20
  MAX_ITEMS = 12

  include Orderable

  belongs_to :page, inverse_of: :blocks
  has_many :items, -> { ordered }, class_name: 'BlockItem', foreign_key: :page_block_id,
                                   inverse_of: :block, dependent: :destroy

  normalizes :heading, with: ->(value) { value.to_s.strip }

  before_validation :append_to_siblings, on: :create

  validates :kind, inclusion: { in: KINDS.keys }
  validates :heading, length: { maximum: 120 }
  validates :body, length: { maximum: 20_000 }
  validates :columns, inclusion: { in: COLUMNS, message: "must be between #{COLUMNS.min} and #{COLUMNS.max}" }
  validate :page_has_room, on: :create

  def self.permitted_for(kind)
    PERMITTED.fetch(kind.to_s, [])
  end

  def label
    KINDS.fetch(kind).fetch(:label)
  end

  # What one of this block's items is called ("slide", "card"); nil for text blocks.
  def item_name
    KINDS.fetch(kind)[:item]
  end

  def holds_items?
    item_name.present?
  end

  def room_for_item?
    items.count < MAX_ITEMS
  end

  # One line for the page editor's list of blocks.
  def summary
    case kind
    when 'carousel' then [counted(items.size, 'slide'), ('live streams first' if show_live_streams?)].compact.join(' · ')
    when 'cards' then "#{counted(items.size, 'card')} in #{counted(columns, 'column')}"
    else MarkdownRenderer.plain_text(body).truncate(90).presence || 'No text yet'
    end
  end

  private

  def sibling_scope
    self.class.where(page_id: page_id)
  end

  def counted(count, noun)
    "#{count} #{noun.pluralize(count)}"
  end

  def page_has_room
    errors.add(:base, "A page can have at most #{MAX_PER_PAGE} blocks") if page && page.blocks.count >= MAX_PER_PAGE
  end
end
