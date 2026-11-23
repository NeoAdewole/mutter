require 'rails_helper'

RSpec.describe 'Admin page blocks', type: :request do
  let(:admin) { create(:user, :admin) }
  let(:page) { create(:page, :published, section: 'content', title: 'Guides') }

  before { sign_in_as(admin) }

  def last_audit
    AuditLog.order(:id).last
  end

  describe 'the blocks panel on the page editor' do
    it 'offers each kind of block to add' do
      get edit_admin_page_path(page)

      expect(response).to have_http_status(:success)
      expect(html.css('[data-no-blocks]')).not_to be_empty
      forms = html.css("form[action='#{admin_page_blocks_path(page)}']")
      expect(forms.map { |form| form.at_css("input[name='kind']")['value'] }).to match_array(%w[carousel cards text])
      expect(forms.map { |form| form.at_css('button, input[type=submit]').text.strip.presence || form.at_css('input[type=submit]')['value'] })
        .to match_array(['Add carousel', 'Add card row', 'Add text'])
    end

    it 'lists the blocks in order with a summary and the right arrows' do
      carousel = create(:page_block, :carousel, page: page)
      create(:block_item, :slide, block: carousel)
      cards = create(:page_block, :cards, page: page, columns: 2, heading: 'Pick one')
      text = create(:page_block, :text, page: page)

      get edit_admin_page_path(page)

      rows = html.css('[data-block-id]')
      expect(rows.map { |row| row['data-block-id'].to_i }).to eq([carousel.id, cards.id, text.id])
      expect(rows.map { |row| row.at_css('[data-summary]').text.strip }).to eq(['1 slide', '0 cards in 2 columns', 'Some text.'])
      expect(rows.last.at_css('[data-summary]').text).not_to include('*')
      expect(rows.first.at_css("form[action='#{move_admin_block_path(carousel)}'] button[value='up']")).to be_nil
      expect(rows.first.at_css("form[action='#{move_admin_block_path(carousel)}'] button[value='down']")).to be_present
      expect(rows.last.at_css("form[action='#{move_admin_block_path(text)}'] button[value='down']")).to be_nil
      expect(rows[1].text).to include('Pick one')
      expect(rows.map { |row| row.at_css("a[href^='/admin/blocks/']")['href'] }).to eq(
        [edit_admin_block_path(carousel), edit_admin_block_path(cards), edit_admin_block_path(text)]
      )
    end

    it 'stops offering more once the page is full' do
      create_list(:page_block, PageBlock::MAX_PER_PAGE, page: page)

      get edit_admin_page_path(page)

      expect(html.css("form[action='#{admin_page_blocks_path(page)}']")).to be_empty
      expect(html.text).to include('most blocks it can hold')
    end
  end

  describe 'POST /admin/pages/:page_id/blocks' do
    it 'adds each kind of block last, opens it for editing and writes to the audit log' do
      %w[carousel cards text].each_with_index do |kind, index|
        expect { post admin_page_blocks_path(page), params: { kind: kind } }.to change(page.blocks, :count).by(1)

        block = page.blocks.reload.last
        expect(block).to have_attributes(kind: kind, position: index)
        expect(response).to redirect_to(edit_admin_block_path(block))
        expect(last_audit).to have_attributes(action: 'page.block_added', target_id: page.id, actor_id: admin.id)
        expect(last_audit.details).to eq('block' => block.label)
      end
    end

    it 'starts a card row with three columns and a carousel without live streams' do
      post admin_page_blocks_path(page), params: { kind: 'cards' }
      post admin_page_blocks_path(page), params: { kind: 'carousel' }

      expect(page.blocks.map { |block| [block.kind, block.columns, block.show_live_streams] }).to eq([['cards', 3, false], ['carousel', 3, false]])
    end

    it 'does not add a block of a kind that does not exist' do
      expect { post admin_page_blocks_path(page), params: { kind: 'video' } }.not_to change(PageBlock, :count)

      expect(response).to redirect_to(edit_admin_page_path(page))
      follow_redirect!
      expect(html.text).to include('Kind is not included')
      expect(AuditLog.count).to eq(0)
    end

    it 'refuses a 21st block' do
      create_list(:page_block, PageBlock::MAX_PER_PAGE, page: page)

      expect { post admin_page_blocks_path(page), params: { kind: 'text' } }.not_to change(PageBlock, :count)
      follow_redirect!
      expect(html.text).to include('at most 20 blocks')
    end

    it 'is a 404 for a page that does not exist' do
      post admin_page_blocks_path(page_id: 0), params: { kind: 'text' }
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'GET /admin/blocks/:id/edit' do
    it 'shows a carousel as a live-streams switch and its slides' do
      block = create(:page_block, :carousel, page: page)
      slide = create(:block_item, :slide, block: block, alt_text: 'Sunset')

      get edit_admin_block_path(block)

      expect(response).to have_http_status(:success)
      expect(html.at_css("input[type=checkbox][name='page_block[show_live_streams]']")).to be_present
      expect(html.at_css('[data-items-panel] h2').text).to eq('Slides')
      expect(html.at_css("[data-item-id='#{slide.id}'] [data-item-label]").text).to eq('Sunset')
      expect(html.at_css("a[href='#{new_admin_block_item_path(block)}']").text).to eq('Add a slide')
      expect(html.at_css("a[href='#{edit_admin_page_path(page)}']")).to be_present
    end

    it 'shows a card row with a column choice of 1 to 6' do
      block = create(:page_block, :cards, page: page, columns: 4)

      get edit_admin_block_path(block)

      select = html.at_css("select[name='page_block[columns]']")
      expect(select.css('option').map { |option| option['value'] }).to eq(%w[1 2 3 4 5 6])
      expect(select.at_css('option[selected]')['value']).to eq('4')
      expect(html.at_css("input[name='page_block[heading]']")).to be_present
      expect(html.at_css('[data-items-panel] h2').text).to eq('Cards')
    end

    it 'shows a text block as a heading and Markdown, with no items' do
      block = create(:page_block, :text, page: page)

      get edit_admin_block_path(block)

      expect(html.at_css("textarea[name='page_block[body]']").text.strip).to eq('Some **text**.')
      expect(html.css('[data-items-panel]')).to be_empty
    end

    it 'is a 404 for a block that does not exist' do
      get edit_admin_block_path(id: 0)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'PATCH /admin/blocks/:id' do
    it 'saves a card row and audits what changed against the page' do
      block = create(:page_block, :cards, page: page, columns: 3)

      patch admin_block_path(block), params: { page_block: { columns: '5', heading: 'Start here' } }

      expect(response).to redirect_to(edit_admin_block_path(block))
      expect(block.reload).to have_attributes(columns: 5, heading: 'Start here')
      expect(last_audit).to have_attributes(action: 'page.block_updated', target_id: page.id)
      expect(last_audit.details['changes']).to eq('columns' => [3, 5], 'heading' => ['', 'Start here'])
    end

    it 'saves a carousel switch and a text block' do
      carousel = create(:page_block, :carousel, page: page)
      text = create(:page_block, :text, page: page)

      patch admin_block_path(carousel), params: { page_block: { show_live_streams: '1' } }
      patch admin_block_path(text), params: { page_block: { heading: 'Hello', body: 'New **text**' } }

      expect(carousel.reload.show_live_streams).to be true
      expect(text.reload).to have_attributes(heading: 'Hello', body: 'New **text**')
    end

    it 'does not audit a save that changed nothing' do
      block = create(:page_block, :cards, page: page, columns: 3)

      patch admin_block_path(block), params: { page_block: { columns: '3' } }

      expect(last_audit.details['changes']).to eq({})
    end

    it 'rejects a column count outside 1 to 6 and keeps what was saved' do
      block = create(:page_block, :cards, page: page, columns: 3)

      patch admin_block_path(block), params: { page_block: { columns: '9' } }

      expect(response).to have_http_status(422)
      expect(html.at_css('[data-form-errors]').text).to include('Columns must be between 1 and 6')
      expect(block.reload.columns).to eq(3)
      expect(AuditLog.count).to eq(0)
    end

    it 'ignores fields that do not belong to the block, including a change of kind or page' do
      other_page = create(:page, :published, section: 'gaming')
      block = create(:page_block, :cards, page: page)

      patch admin_block_path(block), params: { page_block: { kind: 'text', body: 'Sneaky', show_live_streams: '1', page_id: other_page.id,
                                                             position: 9, columns: '2' } }

      expect(block.reload).to have_attributes(kind: 'cards', body: '', show_live_streams: false, page_id: page.id, position: 0, columns: 2)
    end
  end

  describe 'PATCH /admin/blocks/:id/move' do
    let!(:first) { create(:page_block, :text, page: page, heading: 'First') }
    let!(:second) { create(:page_block, :text, page: page, heading: 'Second') }

    it 'moves a block and audits it' do
      patch move_admin_block_path(second), params: { direction: 'up' }

      expect(response).to redirect_to(edit_admin_page_path(page))
      expect(page.blocks.reload.map(&:heading)).to eq(%w[Second First])
      expect(last_audit).to have_attributes(action: 'page.block_moved', target_id: page.id)
      expect(last_audit.details).to include('direction' => 'up')
    end

    it 'leaves the first block where it is when asked to move it up' do
      patch move_admin_block_path(first), params: { direction: 'up' }
      expect(page.blocks.reload.map(&:heading)).to eq(%w[First Second])
    end

    it 'rejects a direction it does not know' do
      patch move_admin_block_path(first), params: { direction: 'sideways' }

      expect(response).to have_http_status(:bad_request)
      expect(AuditLog.count).to eq(0)
    end
  end

  describe 'DELETE /admin/blocks/:id' do
    it 'removes the block and its items, and audits it' do
      block = create(:page_block, :cards, page: page)
      create_list(:block_item, 2, block: block)

      expect { delete admin_block_path(block) }.to change(PageBlock, :count).by(-1).and change(BlockItem, :count).by(-2)

      expect(response).to redirect_to(edit_admin_page_path(page))
      expect(last_audit).to have_attributes(action: 'page.block_removed', target_id: page.id)
      expect(last_audit.details).to eq('block' => 'Card row')
    end

    it 'does not touch the pages the cards featured' do
      featured = create(:page, :published)
      block = create(:page_block, :cards, page: page)
      create(:block_item, block: block, featured_page: featured)

      delete admin_block_path(block)

      expect(Page.exists?(featured.id)).to be true
    end
  end
end
