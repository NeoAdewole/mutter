# A piece of admin-authored content. Every page belongs to one of the four
# Sections and may sit beneath another page of the same section (up to
# MAX_DEPTH levels). Drafts are only ever visible to admins.
class Page < ApplicationRecord
  MAX_DEPTH = 3
  SLUG_FORMAT = /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/
  # Top-level slugs that would collide with built-in routes.
  RESERVED_ROOT_SLUGS = { 'streaming' => %w[live-chat] }.freeze

  include Hierarchy

  belongs_to :parent, class_name: 'Page', optional: true
  has_many :children, -> { ordered }, class_name: 'Page', foreign_key: :parent_id, inverse_of: :parent,
                                      dependent: :restrict_with_error

  before_validation :generate_slug
  before_validation :append_to_siblings, if: -> { new_record? || parent_id_changed? }

  validates :section, inclusion: { in: ->(_) { Section.keys } }
  validates :title, presence: true
  validates :slug, presence: true, format: { with: SLUG_FORMAT, allow_blank: true },
                   uniqueness: { scope: %i[section parent_id] }
  validate :slug_not_reserved
  validate :parent_is_acceptable

  scope :published, -> { where(published: true) }
  scope :ordered, -> { order(:position, :id) }

  def section_info
    Section.find(section)
  end

  def rendered_body
    MarkdownRenderer.call(body)
  end

  # Swap places with the previous/next sibling. Positions are renumbered first
  # so pages that share a position (or have gaps) still move predictably.
  def move(direction)
    step = { up: -1, down: 1 }.fetch(direction.to_sym) { raise ArgumentError, "unknown direction: #{direction.inspect}" }

    transaction do
      siblings = self.class.where(section: section, parent_id: parent_id).ordered.lock.to_a
      index = siblings.index { |sibling| sibling.id == id }
      target = index + step
      next unless index && target.between?(0, siblings.size - 1)

      siblings[index], siblings[target] = siblings[target], siblings[index]
      siblings.each_with_index { |sibling, position| sibling.update_column(:position, position) }
      self.position = target
    end
  end

  private

  def generate_slug
    self.slug = slug.to_s.strip
    self.slug = title.to_s.parameterize if slug.blank?
  end

  # New pages, and pages moved under a different parent, go last.
  def append_to_siblings
    highest = self.class.where(section: section, parent_id: parent_id).where.not(id: id).maximum(:position)
    self.position = highest ? highest + 1 : 0
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
