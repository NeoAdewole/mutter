require 'rails_helper'

RSpec.describe 'Admin pages', type: :request do
  let(:admin) { create(:user, :admin) }

  before { sign_in_as(admin) }

  describe 'GET /admin/pages' do
    it 'lists pages grouped by section, nested, with their status' do
      guides = create(:page, :published, section: 'content', title: 'Guides')
      create(:page, :draft, section: 'content', parent: guides, title: 'Beginner')
      create(:page, :draft, section: 'gaming', title: 'Reviews')

      get admin_pages_path

      expect(response).to have_http_status(:success)
      Section.all.each { |section| expect(html.text).to include(section.title) }
      rows = html.css('tr[data-page-id]')
      expect(rows.map { |r| r.at_css('[data-title]').text.strip }).to eq(%w[Guides Beginner Reviews])
      expect(rows.map { |r| r['data-status'] }).to eq(%w[published draft draft])
    end

    it 'offers to add a page in each of the four sections' do
      get admin_pages_path
      Section.all.map(&:key).each do |key|
        expect(html.css("a[href='#{new_admin_page_path(section: key)}']")).not_to be_empty
      end
    end

    it 'offers only the sensible actions per row' do
      first = create(:page, :published, section: 'content', title: 'First')
      last = create(:page, :draft, section: 'content', title: 'Last')

      get admin_pages_path

      first_row = html.at_css("tr[data-page-id='#{first.id}']")
      last_row = html.at_css("tr[data-page-id='#{last.id}']")
      expect(first_row.at_css("form[action='#{unpublish_admin_page_path(first)}']")).to be_present
      expect(first_row.at_css("form[action='#{publish_admin_page_path(first)}']")).to be_nil
      expect(last_row.at_css("form[action='#{publish_admin_page_path(last)}']")).to be_present
      expect(first_row.at_css("form[action='#{move_admin_page_path(first)}'] button[value='up']")).to be_nil
      expect(last_row.at_css("form[action='#{move_admin_page_path(last)}'] button[value='down']")).to be_nil
      expect(first_row.at_css("form[action='#{move_admin_page_path(first)}'] button[value='down']")).to be_present
    end

    it 'links to the page itself so drafts can be previewed' do
      draft = create(:page, :draft, section: 'content', slug: 'secret')
      get admin_pages_path
      expect(html.css("a[href='/content/secret']")).not_to be_empty
      expect(draft).to be_persisted
    end
  end

  describe 'GET /admin' do
    it 'shows the page list' do
      get admin_root_path
      expect(response).to have_http_status(:success)
      expect(html.text).to include('Pages')
    end
  end

  describe 'GET /admin/pages/new' do
    it 'renders a form for the chosen section' do
      get new_admin_page_path(section: 'gaming')

      expect(response).to have_http_status(:success)
      expect(html.at_css("input[name='page[section]'][value='gaming']")).to be_present
      expect(html.at_css("input[name='page[title]']")).to be_present
      expect(html.at_css("input[name='page[slug]']")).to be_present
      expect(html.at_css("textarea[name='page[body]']")).to be_present
      expect(html.at_css("input[type='checkbox'][name='page[published]']")).to be_present
    end

    it 'only offers parents from the chosen section' do
      mine = create(:page, section: 'gaming', title: 'Gaming page')
      other = create(:page, section: 'content', title: 'Content page')

      get new_admin_page_path(section: 'gaming')

      values = html.css("select[name='page[parent_id]'] option").map { |o| o['value'] }
      expect(values).to include(mine.id.to_s)
      expect(values).not_to include(other.id.to_s)
    end

    it 'falls back to the first section for an unknown one' do
      get new_admin_page_path(section: 'bogus')
      expect(response).to have_http_status(:success)
      expect(html.at_css("input[name='page[section]']")['value']).to eq('streaming')
    end
  end

  describe 'POST /admin/pages' do
    let(:valid) { { section: 'content', title: 'Getting Started', body: '# Hello', published: '0' } }

    it 'creates a draft, generating the slug, and goes back to the list' do
      expect { post admin_pages_path, params: { page: valid } }.to change(Page, :count).by(1)

      page = Page.last
      expect(page).to have_attributes(section: 'content', title: 'Getting Started', slug: 'getting-started', published: false)
      expect(response).to redirect_to(admin_pages_path)
      follow_redirect!
      expect(response.body).to include('Page created')
    end

    it 'can create a published page directly' do
      post admin_pages_path, params: { page: valid.merge(published: '1') }
      expect(Page.last).to be_published
    end

    it 'can create a sub page under a parent' do
      parent = create(:page, section: 'content')
      post admin_pages_path, params: { page: valid.merge(parent_id: parent.id) }
      expect(Page.last.parent).to eq(parent)
    end

    it 're-renders with the errors and creates nothing when invalid' do
      expect { post admin_pages_path, params: { page: valid.merge(title: '') } }.not_to change(Page, :count)

      expect(response).to have_http_status(422)
      expect(html.at_css('[data-form-errors]').text).to match(/title/i)
      expect(html.at_css("input[name='page[section]']")['value']).to eq('content')
    end

    it 'rejects an unknown section' do
      expect { post admin_pages_path, params: { page: valid.merge(section: 'nope') } }.not_to change(Page, :count)
      expect(response).to have_http_status(422)
    end

    it 'rejects a parent from another section' do
      parent = create(:page, section: 'gaming')
      expect { post admin_pages_path, params: { page: valid.merge(parent_id: parent.id) } }.not_to change(Page, :count)
      expect(response).to have_http_status(422)
    end

    it 'ignores attributes that are not part of the form' do
      post admin_pages_path, params: { page: valid.merge(position: 99, id: 12_345, created_at: '2000-01-01') }
      page = Page.last
      expect(page.position).not_to eq(99)
      expect(page.id).not_to eq(12_345)
      expect(page.created_at.year).to eq(Time.current.year)
    end
  end

  describe 'GET /admin/pages/:id/edit' do
    it 'prefills the form but does not let the section change' do
      page = create(:page, section: 'content', title: 'Existing', body: 'Body text', slug: 'existing')

      get edit_admin_page_path(page)

      expect(html.at_css("input[name='page[title]']")['value']).to eq('Existing')
      expect(html.at_css("input[name='page[slug]']")['value']).to eq('existing')
      expect(html.at_css("textarea[name='page[body]']").text).to include('Body text')
      expect(html.at_css("input[name='page[section]']")).to be_nil
    end

    it 'does not offer the page or its own sub pages as a parent' do
      page = create(:page, section: 'content')
      child = create(:page, section: 'content', parent: page)
      other = create(:page, section: 'content')

      get edit_admin_page_path(page)

      values = html.css("select[name='page[parent_id]'] option").map { |o| o['value'] }
      expect(values).to include(other.id.to_s)
      expect(values).not_to include(page.id.to_s, child.id.to_s)
    end

    it 'is a 404 for a page that does not exist' do
      get edit_admin_page_path(id: 0)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'PATCH /admin/pages/:id' do
    let!(:page) { create(:page, :published, section: 'content', title: 'Old', slug: 'old') }

    it 'updates the page' do
      patch admin_page_path(page), params: { page: { title: 'New', slug: 'new', body: 'Fresh body' } }

      expect(response).to redirect_to(admin_pages_path)
      expect(page.reload).to have_attributes(title: 'New', slug: 'new', body: 'Fresh body')
    end

    it 'cannot move a page to another section' do
      patch admin_page_path(page), params: { page: { section: 'gaming', title: 'Same' } }
      expect(page.reload.section).to eq('content')
    end

    it 're-renders with errors when invalid' do
      patch admin_page_path(page), params: { page: { title: '' } }
      expect(response).to have_http_status(422)
      expect(page.reload.title).to eq('Old')
    end

    it 'refuses a parent that would create a cycle' do
      child = create(:page, section: 'content', parent: page)
      patch admin_page_path(page), params: { page: { parent_id: child.id } }
      expect(response).to have_http_status(422)
      expect(page.reload.parent).to be_nil
    end

    it 'can publish through the form checkbox' do
      draft = create(:page, :draft, section: 'content')
      patch admin_page_path(draft), params: { page: { published: '1' } }
      expect(draft.reload).to be_published
    end
  end

  describe 'DELETE /admin/pages/:id' do
    it 'deletes a page' do
      page = create(:page, section: 'content')
      expect { delete admin_page_path(page) }.to change(Page, :count).by(-1)
      expect(response).to redirect_to(admin_pages_path)
    end

    it 'refuses while the page has sub pages, and says why' do
      page = create(:page, section: 'content')
      create(:page, section: 'content', parent: page)

      expect { delete admin_page_path(page) }.not_to change(Page, :count)

      expect(response).to redirect_to(admin_pages_path)
      follow_redirect!
      expect(response.body).to match(/sub pages/i)
    end
  end

  describe 'PATCH /admin/pages/:id/publish and /unpublish' do
    it 'toggles publication' do
      page = create(:page, :draft, section: 'content')

      patch publish_admin_page_path(page)
      expect(page.reload).to be_published
      expect(response).to redirect_to(admin_pages_path)

      patch unpublish_admin_page_path(page)
      expect(page.reload).not_to be_published
    end
  end

  describe 'PATCH /admin/pages/:id/move' do
    let!(:first_page) { create(:page, section: 'content', title: 'A') }
    let!(:second_page) { create(:page, section: 'content', title: 'B') }

    it 'moves a page up or down among its siblings' do
      patch move_admin_page_path(second_page), params: { direction: 'up' }
      expect(Page.where(section: 'content').ordered.map(&:title)).to eq(%w[B A])
      expect(response).to redirect_to(admin_pages_path)

      patch move_admin_page_path(second_page), params: { direction: 'down' }
      expect(Page.where(section: 'content').ordered.map(&:title)).to eq(%w[A B])
    end

    it 'rejects an unknown direction without changing anything' do
      patch move_admin_page_path(second_page), params: { direction: 'sideways' }
      expect(response).to have_http_status(:bad_request)
      expect(Page.where(section: 'content').ordered.map(&:title)).to eq(%w[A B])
    end
  end
end
