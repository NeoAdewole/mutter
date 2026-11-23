# A slide in a carousel, or a card in a row of cards.
#
# Slides are an image (with alt text) and an optional link. Cards need at least
# something to show, and can *feature an existing page*: whatever a card leaves
# blank (title, text, link) is taken from that page, and anything filled in
# replaces it. A card that features a page which visitors cannot see (a draft)
# is hidden from them, and shows up for admins marked as hidden.
class BlockItem < ApplicationRecord
  # http(s) addresses or a path on this site; never javascript:, data: or //host.
  URL_FORMAT = %r{\A(?:https?://\S+|/(?!/)\S*)\z}i
  URL_MESSAGE = 'must start with http://, https:// or / (a page on this site)'.freeze
  DEFAULT_BUTTON = 'Read more'.freeze
  PERMITTED = {
    'carousel' => %i[image_url alt_text link_url],
    'cards' => %i[featured_page_id title body image_url alt_text link_label link_url]
  }.freeze

  include Orderable

  belongs_to :block, class_name: 'PageBlock', foreign_key: :page_block_id, inverse_of: :items
  belongs_to :featured_page, class_name: 'Page', optional: true, inverse_of: :featuring_items

  normalizes :title, :body, :image_url, :alt_text, :link_label, :link_url, with: ->(value) { value.to_s.strip }

  before_validation :append_to_siblings, on: :create

  validates :title, length: { maximum: 120 }
  validates :body, length: { maximum: 1000 }
  validates :alt_text, length: { maximum: 200 }
  validates :link_label, length: { maximum: 40 }
  validates :image_url, :link_url, length: { maximum: 2000 },
                                   format: { with: URL_FORMAT, message: URL_MESSAGE, allow_blank: true }
  validates :image_url, presence: true, if: :slide?
  validates :alt_text, presence: { message: 'is needed so the image can be described to people who cannot see it' }, if: :slide?
  validate :card_has_content, if: :card?
  validate :featured_page_exists
  validate :block_has_room, on: :create

  def self.permitted_for(kind)
    PERMITTED.fetch(kind.to_s, [])
  end

  def slide?
    block&.kind == 'carousel'
  end

  def card?
    block&.kind == 'cards'
  end

  # ---- what a card shows: its own text, else the featured page's ----

  def shown_title
    title.presence || featured_page&.title.to_s
  end

  def shown_body_html
    return MarkdownRenderer.call(body) if body.present?

    featured_page ? ERB::Util.html_escape(featured_page.excerpt) : ''.html_safe
  end

  def href
    link_url.presence || featured_page&.public_path
  end

  def button_label
    link_label.presence || DEFAULT_BUTTON
  end

  def image_alt
    alt_text.presence || shown_title
  end

  def external?
    href.to_s.match?(%r{\Ahttps?://}i)
  end

  # Is there anything to show at all? (A card whose featured page was deleted, and
  # which had nothing of its own, has nothing.)
  def blank_card?
    shown_title.blank? && body.blank? && image_url.blank? && featured_page.blank?
  end

  # Featuring a page that visitors can't see (yet).
  def hidden_from_visitors?
    featured_page.present? && !featured_page.publicly_visible?
  end

  def visible_to?(admin)
    !blank_card? && (admin || !hidden_from_visitors?)
  end

  # How the editor names this item in lists and in the audit log.
  def label
    shown_title.presence || image_alt.presence || "#{block.item_name} #{position + 1}"
  end

  private

  def sibling_scope
    self.class.where(page_block_id: page_block_id)
  end

  def card_has_content
    return if title.present? || body.present? || image_url.present? || featured_page_id.present?

    errors.add(:base, 'A card needs a title, some text, an image or a page to feature')
  end

  def featured_page_exists
    errors.add(:featured_page, 'no longer exists') if featured_page_id.present? && !Page.exists?(featured_page_id)
  end

  def block_has_room
    return if block.nil? || block.room_for_item?

    errors.add(:base, "A #{block.label.downcase} can hold at most #{PageBlock::MAX_ITEMS} #{block.item_name.pluralize}")
  end
end
