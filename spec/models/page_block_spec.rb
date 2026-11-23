require 'rails_helper'

RSpec.describe PageBlock, type: :model do
  let(:page) { create(:page, :published) }

  describe 'validations' do
    it 'has valid factories for every kind' do
      %i[text carousel cards].each { |kind| expect(build(:page_block, kind, page: page)).to be_valid }
    end

    it 'only accepts the three known kinds' do
      expect(build(:page_block, page: page, kind: 'video')).not_to be_valid
      expect(build(:page_block, page: page, kind: nil)).not_to be_valid
    end

    it 'allows 1 to 6 columns and nothing else' do
      (1..6).each { |n| expect(build(:page_block, :cards, page: page, columns: n)).to be_valid }
      [0, 7, -1].each { |n| expect(build(:page_block, :cards, page: page, columns: n)).not_to be_valid }
    end

    it 'limits the heading to 120 characters and trims it' do
      expect(build(:page_block, page: page, heading: 'x' * 121)).not_to be_valid
      expect(build(:page_block, page: page, heading: '  Hello  ').tap(&:valid?).heading).to eq('Hello')
    end

    it 'holds at most 20 blocks per page' do
      create_list(:page_block, PageBlock::MAX_PER_PAGE, page: page)
      extra = build(:page_block, page: page)

      expect(extra).not_to be_valid
      expect(extra.errors.full_messages.to_sentence).to include('at most 20 blocks')
      expect(build(:page_block, page: create(:page))).to be_valid
    end
  end

  describe 'ordering' do
    it 'puts new blocks last and keeps each page separate' do
      first = create(:page_block, page: page)
      second = create(:page_block, page: page)
      elsewhere = create(:page_block)

      expect(page.blocks.map(&:id)).to eq([first.id, second.id])
      expect([first.position, second.position, elsewhere.position]).to eq([0, 1, 0])
    end

    it 'moves up and down, and stops at the ends' do
      a, b, c = create_list(:page_block, 3, page: page)

      b.move(:up)
      expect(page.blocks.reload.map(&:id)).to eq([b.id, a.id, c.id])
      b.move(:up)
      expect(page.blocks.reload.map(&:id)).to eq([b.id, a.id, c.id])
      c.move('up')
      expect(page.blocks.reload.map(&:id)).to eq([b.id, c.id, a.id])
      b.move(:down)
      expect(page.blocks.reload.map(&:id)).to eq([c.id, b.id, a.id])
    end

    it 'refuses a direction it does not know' do
      expect { create(:page_block, page: page).move(:sideways) }.to raise_error(ArgumentError)
    end
  end

  describe 'items' do
    it 'belong to carousels and card rows, not text blocks' do
      expect(build(:page_block, :carousel).holds_items?).to be true
      expect(build(:page_block, :cards).holds_items?).to be true
      expect(build(:page_block, :text).holds_items?).to be false
    end

    it 'are removed with the block' do
      block = create(:page_block, :cards, page: page)
      create_list(:block_item, 2, block: block)

      expect { block.destroy }.to change(BlockItem, :count).by(-2)
    end

    it 'are removed with the page' do
      block = create(:page_block, :cards, page: page)
      create(:block_item, block: block)

      expect { page.destroy }.to change(PageBlock, :count).by(-1).and change(BlockItem, :count).by(-1)
    end
  end

  describe '#summary' do
    it 'describes each kind in a line' do
      carousel = create(:page_block, :carousel, page: page, show_live_streams: true)
      create(:block_item, :slide, block: carousel)
      cards = create(:page_block, :cards, page: page, columns: 4)
      create_list(:block_item, 2, block: cards)

      expect(carousel.summary).to eq('1 slide · live streams first')
      expect(cards.summary).to eq('2 cards in 4 columns')
      expect(create(:page_block, :text, page: page, body: "Hello\n\nthere").summary).to eq('Hello there')
      expect(create(:page_block, :text, page: page, body: '').summary).to eq('No text yet')
      expect(create(:page_block, :cards, page: page, columns: 1).summary).to eq('0 cards in 1 column')
    end
  end

  describe '.permitted_for' do
    it 'only lets each kind set its own fields' do
      expect(described_class.permitted_for('carousel')).to eq([:show_live_streams])
      expect(described_class.permitted_for('cards')).to contain_exactly(:heading, :columns)
      expect(described_class.permitted_for('text')).to contain_exactly(:heading, :body)
      expect(described_class.permitted_for('bogus')).to eq([])
    end
  end
end
