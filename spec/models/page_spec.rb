require 'rails_helper'

RSpec.describe Page, type: :model do
  describe 'validations' do
    subject(:page) { build(:page) }

    it 'has a valid factory' do
      expect(page).to be_valid
    end

    it { is_expected.to validate_presence_of(:title) }

    it 'only accepts the four known sections' do
      page.section = 'nope'
      expect(page).not_to be_valid
      expect(page.errors[:section]).to be_present
      %w[streaming content gaming community].each do |key|
        page.section = key
        expect(page).to be_valid
      end
    end

    describe 'slug' do
      it 'is generated from the title when left blank' do
        page = build(:page, title: 'Getting Started: Part #1!', slug: '')
        page.valid?
        expect(page.slug).to eq('getting-started-part-1')
      end

      it 'is kept when given' do
        page = build(:page, title: 'Anything', slug: 'custom-slug')
        page.valid?
        expect(page.slug).to eq('custom-slug')
      end

      it 'rejects characters that are not URL-safe' do
        ['Has Space', 'UPPER', 'a/b', 'a.b', '-lead', 'trail-', 'ünï', 'a--b'].each do |bad|
          page.slug = bad
          expect(page).not_to be_valid, "expected #{bad.inspect} to be rejected"
        end
      end

      it 'must be unique among siblings (same section and parent)' do
        create(:page, section: 'content', slug: 'guides')
        dupe = build(:page, section: 'content', slug: 'guides')
        expect(dupe).not_to be_valid
        expect(dupe.errors[:slug]).to be_present
      end

      it 'may repeat in another section' do
        create(:page, section: 'content', slug: 'guides')
        expect(build(:page, section: 'gaming', slug: 'guides')).to be_valid
      end

      it 'may repeat under a different parent' do
        a = create(:page, slug: 'a')
        b = create(:page, slug: 'b')
        create(:page, parent: a, slug: 'intro')
        expect(build(:page, parent: b, slug: 'intro')).to be_valid
      end

      it 'cannot be the reserved live-chat slug at the top of Streaming' do
        expect(build(:page, section: 'streaming', slug: 'live-chat')).not_to be_valid
        expect(build(:page, section: 'content', slug: 'live-chat')).to be_valid
      end

      it 'is enforced by the database too, including for top-level pages' do
        create(:page, section: 'content', slug: 'guides')
        dupe = build(:page, section: 'content', slug: 'guides')
        expect { dupe.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
      end
    end

    describe 'hierarchy' do
      it 'requires a parent to be in the same section' do
        parent = create(:page, section: 'content')
        child = build(:page, section: 'gaming', parent: parent)
        expect(child).not_to be_valid
        expect(child.errors[:parent]).to be_present
      end

      it 'cannot be its own parent or sit beneath its own descendant' do
        a = create(:page)
        b = create(:page, parent: a)
        a.parent = a
        expect(a).not_to be_valid
        a.parent = b
        expect(a).not_to be_valid
      end

      it 'allows nesting up to three levels and no deeper' do
        l1 = create(:page)
        l2 = create(:page, parent: l1)
        l3 = create(:page, parent: l2)
        expect(l3.depth).to eq(3)
        l4 = build(:page, parent: l3)
        expect(l4).not_to be_valid
        expect(l4.errors[:parent]).to be_present
      end

      it 'cannot be moved deeper than the limit when it has sub pages of its own' do
        deep = create(:page, parent: create(:page, parent: create(:page)))
        subtree = create(:page)
        create(:page, parent: subtree)
        subtree.parent = deep
        expect(subtree).not_to be_valid
      end

      it 'refuses to be deleted while it has sub pages' do
        parent = create(:page)
        create(:page, parent: parent)
        expect(parent.destroy).to be(false)
        expect(parent.errors[:base]).to be_present
        expect(described_class.exists?(parent.id)).to be(true)
      end

      it 'can be deleted once it has no sub pages' do
        leaf = create(:page)
        expect { leaf.destroy }.to change(described_class, :count).by(-1)
      end
    end

    describe 'defaults' do
      it 'is a draft by default' do
        expect(described_class.new).not_to be_published
      end

      it 'goes to the end of its siblings when created' do
        first = create(:page, section: 'content')
        second = create(:page, section: 'content')
        other_section = create(:page, section: 'gaming')
        expect(second.position).to be > first.position
        expect(other_section.position).to eq(first.position)
      end
    end
  end

  describe 'paths' do
    it 'builds the public path from the section and the ancestor slugs' do
      a = create(:page, section: 'content', slug: 'guides')
      b = create(:page, section: 'content', parent: a, slug: 'beginner')
      expect(a.public_path).to eq('/content/guides')
      expect(b.public_path).to eq('/content/guides/beginner')
    end

    it 'lists its ancestors, outermost first' do
      a = create(:page)
      b = create(:page, parent: a)
      c = create(:page, parent: b)
      expect(c.ancestors).to eq([a, b])
      expect(a.ancestors).to eq([])
    end
  end

  describe '.find_by_path' do
    let!(:guides) { create(:page, :published, section: 'content', slug: 'guides') }
    let!(:beginner) { create(:page, :published, section: 'content', parent: guides, slug: 'beginner') }

    it 'resolves a top-level page' do
      expect(described_class.find_by_path('content', 'guides')).to eq(guides)
    end

    it 'resolves a nested page' do
      expect(described_class.find_by_path('content', 'guides/beginner')).to eq(beginner)
    end

    it 'returns nil when no such page exists' do
      expect(described_class.find_by_path('content', 'nope')).to be_nil
      expect(described_class.find_by_path('content', 'beginner')).to be_nil
      expect(described_class.find_by_path('gaming', 'guides')).to be_nil
    end

    it 'does not care about empty segments or trailing slashes' do
      expect(described_class.find_by_path('content', 'guides/')).to eq(guides)
    end
  end

  describe 'visibility' do
    it 'is publicly visible only when it and every ancestor are published' do
      parent = create(:page, :published)
      child = create(:page, :published, parent: parent)
      expect(child).to be_publicly_visible

      parent.update!(published: false)
      expect(child.reload).not_to be_publicly_visible
      expect(parent).not_to be_publicly_visible
    end

    it 'is not publicly visible as a draft' do
      expect(create(:page, :draft)).not_to be_publicly_visible
    end
  end

  describe 'ordering' do
    let(:section) { 'content' }
    let!(:first_page) { create(:page, section: section, title: 'A') }
    let!(:second_page) { create(:page, section: section, title: 'B') }
    let!(:third_page) { create(:page, section: section, title: 'C') }

    def order
      described_class.where(section: section, parent_id: nil).ordered.map(&:title)
    end

    it 'orders by position then id' do
      expect(order).to eq(%w[A B C])
    end

    it 'moves a page up past its previous sibling' do
      third_page.move(:up)
      expect(order).to eq(%w[A C B])
    end

    it 'moves a page down past its next sibling' do
      first_page.move(:down)
      expect(order).to eq(%w[B A C])
    end

    it 'does nothing when moving the first page up or the last page down' do
      first_page.move(:up)
      third_page.move(:down)
      expect(order).to eq(%w[A B C])
    end

    it 'only reorders among siblings' do
      child = create(:page, section: section, parent: first_page, title: 'child')
      other = create(:page, section: 'gaming', title: 'other')
      child.move(:up)
      other.move(:down)
      expect(order).to eq(%w[A B C])
    end

    it 'copes with siblings that share a position' do
      described_class.update_all(position: 0)
      third_page.move(:up)
      expect(order).to eq(%w[A C B])
    end

    it 'rejects an unknown direction' do
      expect { first_page.move(:sideways) }.to raise_error(ArgumentError)
    end
  end

  describe '.navigation' do
    it 'returns published pages as a tree per section, in order, with drafts left out' do
      a = create(:page, :published, section: 'content', title: 'A')
      create(:page, :draft, section: 'content', title: 'Draft')
      b = create(:page, :published, section: 'content', title: 'B')
      a1 = create(:page, :published, section: 'content', parent: a, title: 'A1')
      create(:page, :draft, section: 'content', parent: a, title: 'A2 draft')
      create(:page, :published, section: 'gaming', title: 'G')

      nav = described_class.navigation
      expect(nav.keys).to match_array(%w[streaming content gaming community])
      expect(nav['content'].map { |n| n.page.title }).to eq(%w[A B])
      expect(nav['content'].first.children.map(&:page)).to eq([a1])
      expect(nav['content'].last.page).to eq(b)
      expect(nav['gaming'].map { |n| n.page.title }).to eq(['G'])
      expect(nav['streaming']).to eq([])
    end

    it 'leaves out published pages whose parent is a draft' do
      draft_parent = create(:page, :draft, section: 'content')
      create(:page, :published, section: 'content', parent: draft_parent)
      expect(described_class.navigation['content']).to eq([])
    end

    it 'costs one query regardless of size' do
      parent = create(:page, :published)
      3.times { create(:page, :published, parent: parent) }
      queries = []
      callback = ->(*, payload) { queries << payload[:sql] unless payload[:name] == 'SCHEMA' }
      ActiveSupport::Notifications.subscribed(callback, 'sql.active_record') { described_class.navigation }
      expect(queries.size).to eq(1)
    end
  end

  describe '.rows_for' do
    it 'flattens a section depth-first in order, with depth and first/last flags, drafts included' do
      a = create(:page, :published, section: 'content', title: 'A')
      b = create(:page, :draft, section: 'content', title: 'B')
      a1 = create(:page, section: 'content', parent: a, title: 'A1')
      create(:page, section: 'gaming', title: 'Other section')

      rows = described_class.rows_for('content')

      expect(rows.map { |r| [r.page, r.depth, r.first_sibling, r.last_sibling] }).to eq(
        [[a, 1, true, false], [a1, 2, true, true], [b, 1, false, true]]
      )
    end
  end

  describe '.parent_choices' do
    it 'excludes the page itself and everything beneath it, and other sections' do
      page = create(:page, section: 'content', title: 'Me')
      create(:page, section: 'content', parent: page, title: 'My child')
      other = create(:page, section: 'content', title: 'Other')
      create(:page, section: 'gaming', title: 'Elsewhere')

      expect(described_class.parent_choices(page).map { |r| r.page.title }).to eq(['Other'])
      expect(described_class.parent_choices(other).map { |r| r.page.title }).to match_array(['Me', 'My child'])
    end

    it 'excludes parents that would push the page (and its sub pages) past the depth limit' do
      l1 = create(:page, section: 'content', title: 'L1')
      l2 = create(:page, section: 'content', parent: l1, title: 'L2')
      create(:page, section: 'content', parent: l2, title: 'L3')
      leaf = create(:page, section: 'content', title: 'Leaf')
      with_child = create(:page, section: 'content', title: 'With child')
      create(:page, section: 'content', parent: with_child, title: 'Its child')

      expect(described_class.parent_choices(leaf).map { |r| r.page.title }).to include('L1', 'L2', 'With child')
      expect(described_class.parent_choices(leaf).map { |r| r.page.title }).not_to include('L3')
      expect(described_class.parent_choices(with_child).map { |r| r.page.title }).to include('L1')
      expect(described_class.parent_choices(with_child).map { |r| r.page.title }).not_to include('L2', 'L3')
    end

    it 'offers every page of the section to a new page' do
      create(:page, section: 'content', title: 'One')
      expect(described_class.parent_choices(described_class.new(section: 'content')).size).to eq(1)
    end
  end

  describe 'moving to another parent' do
    it 'goes to the end of its new siblings' do
      parent = create(:page, section: 'content')
      create(:page, section: 'content', parent: parent, title: 'existing')
      mover = create(:page, section: 'content', title: 'mover')

      mover.update!(parent: parent)

      expect(parent.children.reload.map(&:title)).to eq(%w[existing mover])
    end
  end

  describe '#rendered_body' do
    it 'renders the Markdown body through the sanitizer' do
      page = build(:page, body: "# Hi\n\n<script>alert(1)</script>")
      expect(page.rendered_body).to include('<h1>Hi</h1>')
      expect(page.rendered_body).not_to include('<script')
    end
  end
end
