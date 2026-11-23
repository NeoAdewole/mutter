require 'rails_helper'

RSpec.describe 'Admin: editing Home, About and the landing pages', type: :request do
  let(:admin) { create(:user, :admin) }
  let(:home) { SitePages.page('home') }
  let(:about) { SitePages.page('about') }

  before { sign_in_as(admin) }

  def last_audit
    AuditLog.order(:id).last
  end

  describe 'GET /admin/pages' do
    it 'lists the six site pages first, with Edit and View but no publish, move or delete' do
      get admin_pages_path

      rows = html.css('[data-site-page]')
      expect(rows.map { |row| row['data-site-page'] }).to eq(%w[home about streaming content gaming community])
      rows.each do |row|
        expect(row.css('a').map(&:text)).to eq(%w[View Edit])
        expect(row.css('form')).to be_empty
      end
      expect(rows.first.at_css("a[href='#{edit_admin_page_path(home)}']")).to be_present
      expect(rows.first.at_css("a[href='/']")).to be_present
      expect(html.at_css('[data-site-pages]').text).to include('always stay published')
    end

    it 'keeps site pages out of the section lists' do
      get admin_pages_path
      expect(html.css('tr[data-page-id]')).to be_empty
    end
  end

  describe 'GET /admin/pages/:id/edit' do
    it 'edits the title, heading switch and text, but not the address, place or published state' do
      get edit_admin_page_path(about)

      expect(response).to have_http_status(:success)
      expect(html.at_css('h1').text).to eq('Edit site page')
      %w[title body show_title].each { |field| expect(html.at_css("[name='page[#{field}]']")).to be_present }
      %w[slug parent_id published].each { |field| expect(html.at_css("[name='page[#{field}]']")).to be_nil }
      expect(html.at_css("main a[href='/about']").text).to eq('View')
    end

    it 'shows what is on Home as blocks that can be edited' do
      get edit_admin_page_path(home)

      rows = html.css('[data-block-id]')
      expect(rows.map { |row| row['data-kind'] }).to eq(%w[carousel cards text])
      expect(rows.map { |row| row.at_css('[data-summary]').text.strip }.first(2)).to eq(['4 slides · live streams first', '4 cards in 4 columns'])
    end
  end

  describe 'PATCH /admin/pages/:id' do
    it 'saves a new title, text and heading switch, and audits it as a site page' do
      patch admin_page_path(about), params: { page: { title: 'Who we are', body: 'New text', show_title: '0' } }

      expect(response).to redirect_to(admin_pages_path)
      expect(about.reload).to have_attributes(title: 'Who we are', body: 'New text', show_title: false)
      expect(last_audit).to have_attributes(action: 'page.updated', target_label: 'Site page: Who we are')
    end

    it 'keeps the address, place and published state however they are asked to change' do
      patch admin_page_path(about), params: { page: { title: 'About', slug: 'elsewhere', published: '0', parent_id: create(:page).id, section: 'gaming' } }

      expect(about.reload).to have_attributes(slug: 'about', published: true, parent_id: nil, section: nil, system_key: 'about')
      expect(about.public_path).to eq('/about')
    end

    it 'needs a title' do
      patch admin_page_path(about), params: { page: { title: '' } }

      expect(response).to have_http_status(422)
      expect(about.reload.title).to eq('About Us')
    end
  end

  describe 'what cannot be done to a site page' do
    it 'refuses to unpublish, publish, move or delete it, and says why' do
      before = about.attributes

      patch unpublish_admin_page_path(about)
      patch publish_admin_page_path(about)
      patch move_admin_page_path(about), params: { direction: 'down' }
      expect { delete admin_page_path(about) }.not_to change(Page, :count)

      expect(response).to redirect_to(admin_pages_path)
      follow_redirect!
      expect(html.text).to include('part of the site')
      expect(about.reload.attributes).to eq(before)
      expect(AuditLog.count).to eq(0)
    end
  end

  describe 'creating an ordinary page' do
    it 'can now hide its title, and an ordinary page still has an address and a place' do
      post admin_pages_path, params: { page: { section: 'content', title: 'Quiet', show_title: '0' } }
      page = Page.find_by!(title: 'Quiet')

      expect(page.show_title).to be false
      get edit_admin_page_path(page)
      %w[slug parent_id published].each { |field| expect(html.at_css("[name='page[#{field}]']")).to be_present }
    end
  end
end
