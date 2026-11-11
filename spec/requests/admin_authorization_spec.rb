require 'rails_helper'

# Every admin endpoint, as a guest, a regular user and an admin. The point of
# this file is that authorization is enforced by the server on EVERY action,
# not that the links happen to be hidden.
RSpec.describe 'Admin authorization', type: :request do
  let!(:target) { create(:page, :draft, section: 'content', title: 'Target', slug: 'target') }
  let!(:sibling) { create(:page, :draft, section: 'content', title: 'Sibling', slug: 'sibling') }

  # [description, verb, path-lambda, params]
  let(:endpoints) do
    {
      'admin root' => [:get, -> { admin_root_path }, {}],
      'index' => [:get, -> { admin_pages_path }, {}],
      'new' => [:get, -> { new_admin_page_path(section: 'content') }, {}],
      'create' => [:post, -> { admin_pages_path }, { page: { section: 'content', title: 'Made', body: 'x' } }],
      'edit' => [:get, -> { edit_admin_page_path(target) }, {}],
      'update' => [:patch, -> { admin_page_path(target) }, { page: { title: 'Changed' } }],
      'publish' => [:patch, -> { publish_admin_page_path(target) }, {}],
      'unpublish' => [:patch, -> { unpublish_admin_page_path(target) }, {}],
      'move' => [:patch, -> { move_admin_page_path(sibling) }, { direction: 'up' }],
      # Last: it removes the page the other endpoints act on.
      'destroy' => [:delete, -> { admin_page_path(target) }, {}]
    }
  end

  def request_endpoint(name)
    verb, path, params = endpoints.fetch(name)
    public_send(verb, instance_exec(&path), params: params)
  end

  def snapshot
    [Page.count, Page.order(:id).pluck(:id, :title, :published, :position, :body)]
  end

  describe 'as a guest' do
    it 'sends every endpoint to the login page without changing anything' do
      before = snapshot
      expect(endpoints.keys.size).to eq(10)
      endpoints.each_key do |name|
        request_endpoint(name)
        expect(response).to redirect_to(new_session_path), "#{name} should redirect a guest to login"
      end
      expect(snapshot).to eq(before)
    end
  end

  describe 'as a regular (non-admin) user' do
    before { sign_in_as(create(:user)) }

    it 'refuses every endpoint with a plain 404, without changing anything' do
      before = snapshot
      endpoints.each_key do |name|
        request_endpoint(name)
        expect(response).to have_http_status(:not_found), "#{name} should be refused for a non-admin"
        expect(response.body).not_to match(/admin/i), "#{name} must not reveal the admin area"
      end
      expect(snapshot).to eq(before)
    end

    it 'does not gain admin rights by sending an admin parameter' do
      patch registration_path, params: { user: { admin: true, firstname: 'Sneaky' } }
      get admin_pages_path
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'as an admin' do
    before { sign_in_as(create(:user, :admin)) }

    it 'is allowed through every endpoint' do
      endpoints.each_key do |name|
        request_endpoint(name)
        expect(response.status).to be_between(200, 399), "#{name} returned #{response.status} for an admin"
        expect(response).not_to redirect_to(new_session_path), "#{name} sent an admin to login"
      end
    end
  end

  describe 'after admin rights are revoked' do
    it 'takes effect on the very next request' do
      user = create(:user, :admin)
      sign_in_as(user)
      get admin_pages_path
      expect(response).to have_http_status(:success)

      user.update!(admin: false)
      get admin_pages_path
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'admin can not be granted through public forms' do
    it 'ignores an admin parameter on sign-up' do
      post registration_path, params: {
        user: { email: 'evil@example.com', firstname: 'E', lastname: 'V', username: 'evil', admin: true,
                password: 'securepass', password_confirmation: 'securepass' }
      }
      expect(User.find_by!(email: 'evil@example.com')).not_to be_admin
    end

    it 'ignores an admin parameter on profile update' do
      user = create(:user)
      sign_in_as(user)
      patch registration_path, params: { user: { firstname: 'Changed', admin: true } }
      expect(user.reload.firstname).to eq('Changed')
      expect(user).not_to be_admin
    end
  end
end
