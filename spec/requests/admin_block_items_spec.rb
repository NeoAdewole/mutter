require 'rails_helper'

RSpec.describe 'Admin slides and cards', type: :request do
  let(:admin) { create(:user, :admin) }
  let(:page) { create(:page, :published, section: 'content', title: 'Guides') }
  let(:carousel) { create(:page_block, :carousel, page: page) }
  let(:cards) { create(:page_block, :cards, page: page) }

  before { sign_in_as(admin) }

  def last_audit
    AuditLog.order(:id).last
  end

  describe 'GET /admin/blocks/:block_id/items/new' do
    it 'asks for an image, a description and a link for a slide, and nothing about pages' do
      get new_admin_block_item_path(carousel)

      expect(response).to have_http_status(:success)
      %w[image_url alt_text link_url].each { |field| expect(html.at_css("[name='block_item[#{field}]']")).to be_present }
      %w[featured_page_id title body link_label].each { |field| expect(html.at_css("[name='block_item[#{field}]']")).to be_nil }
      expect(html.at_css("input[name='block_item[image_url]']")['required']).to be_present
    end

    it 'lets a card feature one of the pages, grouped with site pages first and drafts marked' do
      cards # the block's own page ("Guides") comes first
      tips = create(:page, :published, section: 'content', title: 'Tips')
      create(:page, :published, section: 'content', parent: tips, title: 'Beginner')
      create(:page, :draft, section: 'gaming', title: 'Secret review')

      get new_admin_block_item_path(cards)

      select = html.at_css("select[name='block_item[featured_page_id]']")
      expect(select.css('optgroup').map { |group| group['label'] }).to eq(['Site pages', 'Content', 'Gaming'])
      site = select.at_css("optgroup[label='Site pages']").css('option').map(&:text)
      expect(site).to eq(['Home (/)', 'About Us (/about)', 'Streaming (/streaming)', 'Content (/content)', 'Gaming (/gaming)', 'Community (/community)'])
      expect(select.at_css("optgroup[label='Content']").css('option').map(&:text)).to eq(['Guides', 'Tips', '— Beginner'])
      expect(select.at_css("optgroup[label='Gaming']").css('option').map(&:text)).to eq(['Secret review (draft)'])
      expect(select.at_css('option[value=""]').text).to include('None')
      %w[title body image_url alt_text link_label link_url].each { |field| expect(html.at_css("[name='block_item[#{field}]']")).to be_present }
    end

    it 'is a 404 for a text block, which has no items' do
      get new_admin_block_item_path(create(:page_block, :text, page: page))
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST /admin/blocks/:block_id/items' do
    it 'adds a slide, last, and audits it against the page' do
      create(:block_item, :slide, block: carousel)
      attrs = { image_url: 'https://images.example.com/a.jpg', alt_text: 'A lake', link_url: '/content/lakes' }

      expect { post admin_block_items_path(carousel), params: { block_item: attrs } }.to change(carousel.items, :count).by(1)

      expect(response).to redirect_to(edit_admin_block_path(carousel))
      expect(carousel.items.last).to have_attributes(attrs.merge(position: 1))
      expect(last_audit).to have_attributes(action: 'page.block_updated', target_id: page.id)
      expect(last_audit.details).to eq('block' => 'Carousel', 'item' => 'added slide “A lake”')
    end

    it 'adds a card that features a page' do
      featured = create(:page, :published, title: 'Beginner guide')

      post admin_block_items_path(cards), params: { block_item: { featured_page_id: featured.id, link_label: 'Start' } }

      expect(cards.items.last).to have_attributes(featured_page: featured, title: '', link_label: 'Start')
      follow_redirect!
      expect(html.at_css('[data-featured]').text).to include('Features “Beginner guide”')
    end

    it 'adds a fully custom card' do
      attrs = { title: 'Hello', body: 'Some **words**', image_url: 'https://images.example.com/c.png', alt_text: 'A cat',
                link_label: 'Go', link_url: 'https://example.com' }

      post admin_block_items_path(cards), params: { block_item: attrs }

      expect(cards.items.last).to have_attributes(attrs)
    end

    it 'says what is wrong with a slide and adds nothing' do
      expect { post admin_block_items_path(carousel), params: { block_item: { image_url: 'https://images.example.com/a.jpg' } } }
        .not_to change(BlockItem, :count)

      expect(response).to have_http_status(422)
      expect(html.at_css('[data-form-errors]').text).to include('Alt text is needed so the image can be described')
      expect(AuditLog.count).to eq(0)
    end

    it 'refuses an empty card' do
      post admin_block_items_path(cards), params: { block_item: { link_label: 'Go' } }

      expect(response).to have_http_status(422)
      expect(html.at_css('[data-form-errors]').text).to include('A card needs a title')
    end

    it 'refuses links and images that are not web addresses or site paths' do
      post admin_block_items_path(cards), params: { block_item: { title: 'x', link_url: 'javascript:alert(1)', image_url: 'data:text/html,hi' } }

      expect(response).to have_http_status(422)
      expect(html.at_css('[data-form-errors]').text).to include('Link url must start with').and include('Image url must start with')
      expect(cards.items.count).to eq(0)
    end

    it 'says so, rather than failing, when the featured page is not there' do
      post admin_block_items_path(cards), params: { block_item: { title: 'x', featured_page_id: 0 } }

      expect(response).to have_http_status(422)
      expect(html.at_css('[data-form-errors]').text).to include('Featured page no longer exists')
    end

    it 'refuses a 13th item' do
      create_list(:block_item, PageBlock::MAX_ITEMS, block: cards)

      post admin_block_items_path(cards), params: { block_item: { title: 'One too many' } }

      expect(response).to have_http_status(422)
      expect(html.at_css('[data-form-errors]').text).to include('at most 12 cards')
    end

    it 'ignores fields it was not offered, such as the block or position' do
      other = create(:page_block, :cards, page: page)

      post admin_block_items_path(cards), params: { block_item: { title: 'x', page_block_id: other.id, position: 7 } }

      expect(BlockItem.last).to have_attributes(page_block_id: cards.id, position: 0)
    end

    it 'does not take fields that belong to cards on a slide' do
      post admin_block_items_path(carousel), params: { block_item: { image_url: 'https://images.example.com/a.jpg', alt_text: 'x',
                                                                     title: 'Nope', featured_page_id: page.id } }

      expect(BlockItem.last).to have_attributes(title: '', featured_page_id: nil)
    end

    it 'is a 404 for a text block' do
      post admin_block_items_path(create(:page_block, :text, page: page)), params: { block_item: { title: 'x' } }
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'PATCH /admin/items/:id' do
    let!(:card) { create(:block_item, block: cards, title: 'Old') }

    it 'saves and audits' do
      patch admin_item_path(card), params: { block_item: { title: 'New', link_url: '/gaming' } }

      expect(response).to redirect_to(edit_admin_block_path(cards))
      expect(card.reload).to have_attributes(title: 'New', link_url: '/gaming')
      expect(last_audit.details).to eq('block' => 'Card row', 'item' => 'edited card “New”')
    end

    it 'can stop featuring a page' do
      card.update!(featured_page: create(:page, :published))

      patch admin_item_path(card), params: { block_item: { featured_page_id: '' } }

      expect(card.reload.featured_page).to be_nil
    end

    it 'keeps what was saved when the new values are not valid' do
      patch admin_item_path(card), params: { block_item: { title: '', link_url: 'nonsense' } }

      expect(response).to have_http_status(422)
      expect(card.reload.title).to eq('Old')
      expect(AuditLog.count).to eq(0)
    end

    it 'cannot move a card to another block' do
      other = create(:page_block, :cards, page: page)

      patch admin_item_path(card), params: { block_item: { page_block_id: other.id } }

      expect(card.reload.page_block_id).to eq(cards.id)
    end
  end

  describe 'PATCH /admin/items/:id/move' do
    let!(:first) { create(:block_item, block: cards, title: 'First') }
    let!(:second) { create(:block_item, block: cards, title: 'Second') }

    it 'reorders and audits against the page' do
      patch move_admin_item_path(second), params: { direction: 'up' }

      expect(response).to redirect_to(edit_admin_block_path(cards))
      expect(cards.items.reload.map(&:title)).to eq(%w[Second First])
      expect(last_audit).to have_attributes(action: 'page.block_moved', target_id: page.id)
      expect(last_audit.details).to eq('block' => 'Card row', 'item' => 'Second', 'direction' => 'up')
    end

    it 'shows arrows only where they can be used' do
      get edit_admin_block_path(cards)

      expect(html.at_css("[data-item-id='#{first.id}'] button[value='up']")).to be_nil
      expect(html.at_css("[data-item-id='#{first.id}'] button[value='down']")).to be_present
      expect(html.at_css("[data-item-id='#{second.id}'] button[value='down']")).to be_nil
    end

    it 'rejects an unknown direction' do
      patch move_admin_item_path(first), params: { direction: 'x' }
      expect(response).to have_http_status(:bad_request)
    end
  end

  describe 'DELETE /admin/items/:id' do
    it 'removes only the card, keeping the page it featured, and audits it' do
      featured = create(:page, :published)
      card = create(:block_item, block: cards, title: 'Gone', featured_page: featured)

      expect { delete admin_item_path(card) }.to change(BlockItem, :count).by(-1)

      expect(response).to redirect_to(edit_admin_block_path(cards))
      expect(Page.exists?(featured.id)).to be true
      expect(last_audit.details).to eq('block' => 'Card row', 'item' => 'removed card “Gone”')
    end
  end

  describe 'GET /admin/items/:id/edit' do
    it 'fills the form with the card, with its featured page selected' do
      featured = create(:page, :published, title: 'Beginner guide')
      card = create(:block_item, block: cards, title: 'Hi', featured_page: featured)

      get edit_admin_item_path(card)

      expect(html.at_css("input[name='block_item[title]']")['value']).to eq('Hi')
      expect(html.at_css("select[name='block_item[featured_page_id]'] option[selected]")['value']).to eq(featured.id.to_s)
    end
  end
end
