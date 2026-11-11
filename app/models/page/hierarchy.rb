class Page < ApplicationRecord
  # Everything about where a page sits in its section's tree: paths, ancestors,
  # lookups by path, and the flattened/nested listings the menus and admin use.
  module Hierarchy
    extend ActiveSupport::Concern

    # A page and its already-loaded published sub pages, for building menus.
    NavNode = Struct.new(:page, :children)
    # A page in a flattened, ordered tree listing (see Page.rows_for).
    Row = Struct.new(:page, :depth, :first_sibling, :last_sibling)

    class_methods do
      # Resolves "guides/beginner" inside a section by walking down the tree.
      # Returns nil when any step is missing. Does NOT check published state.
      def find_by_path(section, path)
        slugs = path.to_s.split('/').compact_blank
        return nil if slugs.empty?

        slugs.reduce(nil) do |parent, slug|
          page = find_by(section: section, parent_id: parent&.id, slug: slug)
          return nil unless page

          page
        end
      end

      # { 'streaming' => [NavNode, ...], ... } for every section, published pages
      # only, in order. A published page beneath a draft is left out (it isn't
      # reachable publicly either). One query, however large the tree.
      def navigation
        by_parent = published.ordered.group_by(&:parent_id)
        build = lambda do |pages|
          pages.map { |page| NavNode.new(page, build.call(by_parent.fetch(page.id, []))) }
        end

        roots = by_parent.fetch(nil, []).group_by(&:section)
        Section.keys.index_with { |key| build.call(roots.fetch(key, [])) }
      end

      # Every page of a section (drafts included) as a depth-first, ordered list
      # of Rows, for the admin screens. One query.
      def rows_for(section)
        by_parent = where(section: section).ordered.group_by(&:parent_id)
        flatten = lambda do |parent_id, depth|
          siblings = by_parent.fetch(parent_id, [])
          siblings.each_with_index.flat_map do |page, index|
            [Row.new(page, depth, index.zero?, index == siblings.size - 1)] + flatten.call(page.id, depth + 1)
          end
        end
        flatten.call(nil, 1)
      end

      # The rows `page` could legitimately be moved beneath: same section, not
      # itself or one of its own sub pages, and not so deep that its own sub pages
      # would pass MAX_DEPTH.
      def parent_choices(page)
        height = page.subtree_height
        inside_page_depth = nil
        rows_for(page.section).select do |row|
          inside_page_depth = nil if inside_page_depth && row.depth <= inside_page_depth
          inside_page_depth = row.depth if row.page.id == page.id
          inside_page_depth.nil? && row.depth + height <= Page::MAX_DEPTH
        end
      end
    end

    def ancestors
      chain = []
      node = parent
      while node && chain.size <= Page::MAX_DEPTH && !chain.include?(node) && node != self
        chain.unshift(node)
        node = node.parent
      end
      chain
    end

    # 1 for a top-level page.
    def depth
      ancestors.size + 1
    end

    def public_path
      "/#{section}/#{(ancestors + [self]).map(&:slug).join('/')}"
    end

    def publicly_visible?
      published? && ancestors.all?(&:published?)
    end

    # Levels in the tree rooted at this page, counting itself (1 for a leaf).
    def subtree_height
      return 1 unless persisted?

      1 + (children.map(&:subtree_height).max || 0)
    end
  end
end
