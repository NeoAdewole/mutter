require 'rails_helper'

RSpec.describe BlockItem, type: :model do
  let(:cards) { create(:page_block, :cards) }
  let(:carousel) { create(:page_block, :carousel) }

  describe 'slides' do
    it 'need an image and a description of it' do
      expect(build(:block_item, :slide, block: carousel)).to be_valid

      no_image = build(:block_item, :slide, block: carousel, image_url: '')
      no_alt = build(:block_item, :slide, block: carousel, alt_text: ' ')
      expect(no_image).not_to be_valid
      expect(no_alt).not_to be_valid
      expect(no_alt.errors[:alt_text].to_sentence).to include('described')
    end
  end

  describe 'cards' do
    it 'need something to show' do
      empty = build(:block_item, block: cards, title: '')

      expect(empty).not_to be_valid
      expect(empty.errors.full_messages.to_sentence).to include('needs a title')
      expect(build(:block_item, block: cards, title: '', body: 'Words')).to be_valid
      expect(build(:block_item, block: cards, title: '', image_url: 'https://x.test/a.png')).to be_valid
      expect(build(:block_item, block: cards, title: '', featured_page: create(:page))).to be_valid
    end
  end

  describe 'addresses' do
    it 'accept web addresses and paths on this site' do
      ['https://example.com/a.png', 'http://example.com/a?b=1', '/content/guides', '/'].each do |url|
        expect(build(:block_item, block: cards, link_url: url, image_url: url)).to be_valid, "expected #{url} to be accepted"
      end
    end

    it 'reject anything that could run script or leave the site by the back door' do
      ['javascript:alert(1)', 'JaVaScRiPt:alert(1)', 'data:text/html;base64,AAAA', '//evil.example.com', 'ftp://example.com',
       'example.com', 'https://has space.example', "https://x.test/\nhttp://y.test"].each do |url|
        item = build(:block_item, block: cards, link_url: url)
        expect(item).not_to be_valid, "expected #{url.inspect} to be rejected"
        expect(item.errors[:link_url]).to be_present
      end
      expect(build(:block_item, block: cards, image_url: 'javascript:alert(1)')).not_to be_valid
    end

    it 'are trimmed' do
      item = build(:block_item, block: cards, title: '  Hi  ', link_url: " https://example.com \n").tap(&:valid?)
      expect([item.title, item.link_url]).to eq(['Hi', 'https://example.com'])
    end
  end

  describe 'limits' do
    it 'holds at most 12 per block' do
      create_list(:block_item, PageBlock::MAX_ITEMS, block: cards)
      extra = build(:block_item, block: cards)

      expect(extra).not_to be_valid
      expect(extra.errors.full_messages.to_sentence).to include('at most 12 cards')
      expect(build(:block_item, block: create(:page_block, :cards))).to be_valid
    end

    it 'keeps text and length limits' do
      expect(build(:block_item, block: cards, title: 'x' * 121)).not_to be_valid
      expect(build(:block_item, block: cards, body: 'x' * 1001)).not_to be_valid
      expect(build(:block_item, block: cards, link_label: 'x' * 41)).not_to be_valid
    end
  end

  describe 'featuring a page' do
    let(:featured) { create(:page, :published, title: 'Beginner guide', body: "## Start here\n\nLearn **all** the things.", slug: 'beginner') }

    it 'takes the title, the start of the text and the address from the page' do
      card = create(:block_item, block: cards, title: '', featured_page: featured)

      expect(card.shown_title).to eq('Beginner guide')
      expect(card.shown_body_html).to eq('Start here Learn all the things.')
      expect(card.href).to eq('/content/beginner')
      expect(card.button_label).to eq('Read more')
    end

    it 'lets anything filled in replace what comes from the page' do
      card = create(:block_item, block: cards, title: 'My title', body: 'My **words**', link_url: 'https://example.com',
                                 link_label: 'Go', featured_page: featured)

      expect(card.shown_title).to eq('My title')
      expect(card.shown_body_html).to include('<strong>words</strong>')
      expect(card.href).to eq('https://example.com')
      expect(card.button_label).to eq('Go')
      expect(card.external?).to be true
    end

    it 'shortens a long text at a word and escapes it' do
      featured.update!(body: "<b>Tom</b> & Jerry #{'word ' * 100}")
      html = create(:block_item, block: cards, title: '', featured_page: featured).shown_body_html

      expect(html.length).to be < 200
      expect(html).to end_with('...')
      expect(html).not_to include('<b>')
      expect(html).to be_html_safe
    end

    it 'cannot name a page that does not exist' do
      card = build(:block_item, block: cards, title: 'x', featured_page_id: 0)

      expect(card).not_to be_valid
      expect(card.errors[:featured_page]).to be_present
    end

    it 'is hidden from visitors while the page is a draft (or sits beneath one), but not from admins' do
      draft = create(:page, :draft)
      card = create(:block_item, block: cards, featured_page: draft)

      expect(card.hidden_from_visitors?).to be true
      expect(card.visible_to?(false)).to be false
      expect(card.visible_to?(true)).to be true

      draft.update!(published: true)
      expect(card.reload.visible_to?(false)).to be true
    end

    it 'keeps what it has of its own when the page is deleted' do
      with_own = create(:block_item, block: cards, title: 'Mine', featured_page: featured)
      only_page = create(:block_item, block: cards, title: '', featured_page: featured)

      featured.destroy!

      expect(with_own.reload.featured_page).to be_nil
      expect(with_own.visible_to?(false)).to be true
      expect(only_page.reload.blank_card?).to be true
      expect(only_page.visible_to?(true)).to be false
    end
  end

  describe 'ordering' do
    it 'is per block, new items last, and movable' do
      a, b = create_list(:block_item, 2, block: cards)
      other = create(:block_item, block: create(:page_block, :cards))

      expect([a.position, b.position, other.position]).to eq([0, 1, 0])
      b.move(:up)
      expect(cards.items.reload.map(&:id)).to eq([b.id, a.id])
    end
  end

  describe '#label' do
    it 'names an item by its title, else its image description, else its place' do
      expect(build(:block_item, block: cards, title: 'Hello').label).to eq('Hello')
      expect(build(:block_item, :slide, block: carousel, alt_text: 'A sunset').label).to eq('A sunset')
      expect(build(:block_item, block: cards, title: '', body: 'Words', position: 2).label).to eq('card 3')
    end
  end
end
