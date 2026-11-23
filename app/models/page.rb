# A piece of admin-authored content. Most pages belong to one of the four
# Sections and may sit beneath another page of the same section (up to
# MAX_DEPTH levels). Drafts are only ever visible to admins.
#
# Site pages (Home, About and each section's landing page) are the exception:
# they have a system_key instead of a section, are created by SitePages, always
# published, and can be edited but not moved, unpublished or deleted.
#
# What a page shows is its title, its main text (`body`, Markdown) and then its
# ordered `blocks` (carousels, rows of cards, more text).
class Page < ApplicationRecord
  MAX_DEPTH = 3
  SLUG_FORMAT = /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/
  # Top-level slugs that would collide with built-in routes.
  RESERVED_ROOT_SLUGS = { 'streaming' => %w[live-chat] }.freeze
  SITE_PATHS = { 'home' => '/', 'about' => '/about' }.freeze
  SYSTEM_KEYS = (SITE_PATHS.keys + Section.keys).freeze

  include Hierarchy
  include Orderable

  belongs_to :parent, class_name: 'Page', optional: true
  has_many :children, -> { ordered }, class_name: 'Page', foreign_key: :parent_id, inverse_of: :parent,
                                      dependent: :restrict_with_error
  has_many :blocks, -> { ordered }, class_name: 'PageBlock', inverse_of: :page, dependent: :destroy
  # Cards that feature this page; the database nulls their link when the page is deleted.
  has_many :featuring_items, class_name: 'BlockItem', foreign_key: :featured_page_id,
                             inverse_of: :featured_page, dependent: :nullify

  before_validation :generate_slug
  before_validation :publish_site_page
  before_validation :append_to_siblings, if: -> { new_record? || parent_id_changed? }

  validates :section, inclusion: { in: ->(_) { Section.keys } }, unless: :site_page?
  validates :section, absence: true, if: :site_page?
  validates :system_key, inclusion: { in: SYSTEM_KEYS }, uniqueness: true, allow_nil: true
  validates :title, presence: true
  validates :slug, presence: true, format: { with: SLUG_FORMAT, allow_blank: true },
                   uniqueness: { scope: %i[section parent_id] }
  validate :slug_not_reserved
  validate :parent_is_acceptable

  scope :published, -> { where(published: true) }
  scope :in_sections, -> { where.not(section: nil) }
  scope :site_pages, -> { where.not(system_key: nil) }

  def site_page?
    system_key.present?
  end

  def section_info
    Section.find(section)
  end

  # How this page is named in the audit log (kept even after it is deleted).
  def audit_label
    site_page? ? "Site page: #{title}" : "#{section_info&.title || section}: #{title}"
  end

  def site_path
    SITE_PATHS.fetch(system_key) { "/#{system_key}" }
  end

  def rendered_body
    MarkdownRenderer.call(body)
  end

  # A short plain-text teaser from the start of the main text, for cards that feature this page.
  def excerpt(length = 160)
    ActionController::Base.helpers.truncate(MarkdownRenderer.plain_text(body), length: length, separator: ' ', escape: false)
  end

  private

  def sibling_scope
    self.class.where(section: section, parent_id: parent_id)
  end

  def generate_slug
    self.slug = slug.to_s.strip
    self.slug = (site_page? ? system_key : title.to_s.parameterize) if slug.blank?
  end

  def publish_site_page
    self.published = true if site_page?
  end

  def slug_not_reserved
    return if parent_id.present?

    errors.add(:slug, 'is reserved for a built-in page') if RESERVED_ROOT_SLUGS.fetch(section, []).include?(slug)
  end

  def parent_is_acceptable
    return unless parent

    if parent.section != section
      errors.add(:parent, 'must be in the same section')
    elsif parent == self || parent.ancestors.include?(self)
      errors.add(:parent, 'cannot be this page or one of its own sub pages')
    elsif parent.depth + subtree_height > MAX_DEPTH
      errors.add(:parent, "would nest pages more than #{MAX_DEPTH} levels deep")
    end
  end
end
