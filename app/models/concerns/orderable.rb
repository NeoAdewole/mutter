# Records that sit in an ordered list among their siblings (pages in a menu,
# blocks on a page, cards in a row). The including model says who the siblings
# are by defining a private `sibling_scope` (a relation that includes the record).
module Orderable
  extend ActiveSupport::Concern

  included do
    scope :ordered, -> { order(:position, :id) }
  end

  # Swap places with the previous/next sibling. Positions are renumbered first
  # so records that share a position (or have gaps) still move predictably.
  def move(direction)
    step = { up: -1, down: 1 }.fetch(direction.to_sym) { raise ArgumentError, "unknown direction: #{direction.inspect}" }

    transaction do
      siblings = sibling_scope.ordered.lock.to_a
      index = siblings.index { |sibling| sibling.id == id }
      target = index + step
      next unless index && target.between?(0, siblings.size - 1)

      siblings[index], siblings[target] = siblings[target], siblings[index]
      siblings.each_with_index { |sibling, position| sibling.update_column(:position, position) }
      self.position = target
    end
  end

  private

  # New records go last.
  def append_to_siblings
    highest = sibling_scope.where.not(id: id).maximum(:position)
    self.position = highest ? highest + 1 : 0
  end
end
