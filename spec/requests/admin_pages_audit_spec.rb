require 'rails_helper'

# Page management predates the audit log; this checks every page action now leaves a record.
RSpec.describe 'Admin page actions in the audit log', type: :request do
  let(:admin) { create(:user, :admin) }
  def latest
    AuditLog.order(:id).last
  end

  before { sign_in_as(admin) }

  it 'records creating a page' do
    post admin_pages_path, params: { page: { section: 'content', title: 'Guides', body: 'x', published: '1' } }

    expect(latest).to have_attributes(action: 'page.created', actor: admin, target_label: 'Content: Guides')
    expect(latest.details).to eq('published' => true)
  end

  it 'records editing a page, with short fields as old and new but not the body text' do
    page = create(:page, section: 'content', title: 'Old', body: 'short')

    patch admin_page_path(page), params: { page: { title: 'New', body: 'y' * 500 } }

    expect(latest).to have_attributes(action: 'page.updated', target_id: page.id)
    expect(latest.details['changes']).to eq('title' => %w[Old New], 'body' => 'changed')
  end

  it 'records publishing, unpublishing and reordering' do
    page = create(:page, :draft, section: 'content', title: 'A')
    create(:page, :draft, section: 'content', title: 'B')

    patch publish_admin_page_path(page)
    expect(latest.action).to eq('page.published')

    patch unpublish_admin_page_path(page)
    expect(latest.action).to eq('page.unpublished')

    patch move_admin_page_path(page), params: { direction: 'down' }
    expect(latest).to have_attributes(action: 'page.moved')
    expect(latest.details).to eq('direction' => 'down')
  end

  it 'records deleting a page, by name, and nothing when the delete is refused' do
    parent = create(:page, section: 'content', title: 'Parent')
    create(:page, section: 'content', title: 'Child', parent: parent)

    expect { delete admin_page_path(parent) }.not_to change(AuditLog, :count)

    leaf = create(:page, section: 'gaming', title: 'Leaf')
    delete admin_page_path(leaf)
    expect(latest).to have_attributes(action: 'page.deleted', target_label: 'Gaming: Leaf')
  end

  it "doesn't record a page that failed to save" do
    expect do
      post admin_pages_path, params: { page: { section: 'content', title: '' } }
    end.not_to change(AuditLog, :count)
  end
end
