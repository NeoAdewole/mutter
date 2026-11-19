require 'rails_helper'

# Every admin endpoint, as a guest, a regular user and an admin. The point of
# this file is that authorization is enforced by the server on EVERY action,
# not that the links happen to be hidden.
RSpec.describe 'Admin authorization', type: :request do
  let!(:target) { create(:page, :draft, section: 'content', title: 'Target', slug: 'target') }
  let!(:sibling) { create(:page, :draft, section: 'content', title: 'Sibling', slug: 'sibling') }
  let!(:subject_user) { create(:user, username: 'subject') }
  let!(:subject_identity) { create(:identity, user: subject_user, provider: 'github', uuid: 'subject-gh') }

  # 'controller#action' => [verb, path-lambda, params]
  let(:endpoints) do
    {
      'admin/dashboard#show' => [:get, -> { admin_root_path }, {}],
      'admin/pages#index' => [:get, -> { admin_pages_path }, {}],
      'admin/pages#new' => [:get, -> { new_admin_page_path(section: 'content') }, {}],
      'admin/pages#create' => [:post, -> { admin_pages_path }, { page: { section: 'content', title: 'Made', body: 'x' } }],
      'admin/pages#edit' => [:get, -> { edit_admin_page_path(target) }, {}],
      'admin/pages#update' => [:patch, -> { admin_page_path(target) }, { page: { title: 'Changed' } }],
      'admin/pages#publish' => [:patch, -> { publish_admin_page_path(target) }, {}],
      'admin/pages#unpublish' => [:patch, -> { unpublish_admin_page_path(target) }, {}],
      'admin/pages#move' => [:patch, -> { move_admin_page_path(sibling) }, { direction: 'up' }],
      'admin/users#index' => [:get, -> { admin_users_path }, {}],
      'admin/users#show' => [:get, -> { admin_user_path(subject_user) }, {}],
      'admin/users#edit' => [:get, -> { edit_admin_user_path(subject_user) }, {}],
      'admin/users#update' => [:patch, -> { admin_user_path(subject_user) }, { user: { firstname: 'Changed' } }],
      'admin/users#grant_admin' => [:patch, -> { grant_admin_admin_user_path(subject_user) }, {}],
      'admin/users#revoke_admin' => [:patch, -> { revoke_admin_admin_user_path(subject_user) }, {}],
      'admin/users#suspend' => [:patch, -> { suspend_admin_user_path(subject_user) }, { reason: 'x' }],
      'admin/users#unsuspend' => [:patch, -> { unsuspend_admin_user_path(subject_user) }, {}],
      'admin/users#send_password_reset' => [:post, -> { send_password_reset_admin_user_path(subject_user) }, {}],
      'admin/identities#destroy' => [:delete, -> { admin_user_identity_path(subject_user, subject_identity) }, {}],
      'admin/audit_logs#index' => [:get, -> { admin_audit_logs_path }, {}],
      'admin/settings#show' => [:get, -> { admin_settings_path }, {}],
      'admin/settings#update' => [:patch, -> { admin_settings_path }, { settings: { signups_enabled: '0' } }],
      'admin/system#show' => [:get, -> { admin_system_path }, {}],
      'admin/system#clear_cache' => [:post, -> { clear_cache_admin_system_path }, {}],
      # Last: these remove records the other endpoints act on.
      'admin/users#destroy' => [:delete, -> { admin_user_path(subject_user) }, {}],
      'admin/pages#destroy' => [:delete, -> { admin_page_path(target) }, {}]
    }
  end

  def request_endpoint(name)
    verb, path, params = endpoints.fetch(name)
    public_send(verb, instance_exec(&path), params: params)
  end

  # Everything an admin action could change.
  def snapshot
    [
      Page.order(:id).pluck(:id, :title, :published, :position, :body),
      User.order(:id).pluck(:id, :username, :firstname, :admin, :suspended_at),
      Identity.count,
      AuditLog.count,
      SiteSetting.count
    ]
  end

  it 'has a test for every admin route, so a new endpoint cannot be added unprotected-and-untested' do
    routed = Rails.application.routes.routes
                  .map { |route| "#{route.defaults[:controller]}##{route.defaults[:action]}" if route.defaults[:controller].to_s.start_with?('admin/') }
                  .compact.uniq
    expect(endpoints.keys).to match_array(routed)
  end

  describe 'as a guest' do
    it 'sends every endpoint to the login page without changing anything' do
      before = snapshot
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

  describe 'as a suspended admin' do
    it 'is treated as signed out on every endpoint' do
      admin = create(:user, :admin)
      sign_in_as(admin)
      admin.suspend!
      before = snapshot

      endpoints.each_key do |name|
        request_endpoint(name)
        expect(response).to redirect_to(new_session_path), "#{name} should refuse a suspended admin"
      end
      expect(snapshot).to eq(before)
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

    it 'ignores suspension and sign-in bookkeeping parameters on profile update' do
      user = create(:user)
      sign_in_as(user)
      patch registration_path, params: { user: { firstname: 'Changed', suspended_at: 1.day.ago, sign_in_count: 99 } }
      expect(user.reload).not_to be_suspended
      expect(user.sign_in_count).to eq(1)
    end
  end
end
