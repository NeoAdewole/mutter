require 'rails_helper'

RSpec.describe 'Admin user management', type: :request do
  let(:admin) { create(:user, :admin, username: 'rootadmin') }
  def latest_audit
    AuditLog.order(:id).last
  end

  before { sign_in_as(admin) }

  def usernames
    html.css('tr[data-user-id] td:first-child a').map(&:text)
  end

  describe 'GET /admin/users' do
    it 'lists users newest first, with their status badges' do
      older = create(:user, username: 'older', created_at: 3.days.ago)
      newer = create(:user, :admin, username: 'newer', created_at: 1.day.ago)
      suspended = create(:user, username: 'banned', created_at: 2.days.ago).tap(&:suspend!)

      get admin_users_path

      expect(response).to have_http_status(:success)
      expect(usernames).to eq(%w[rootadmin newer banned older])
      rows = html.css('tr[data-user-id]').index_by { |row| row['data-user-id'].to_i }
      expect(rows[newer.id].css('[data-badge="admin"]')).not_to be_empty
      expect(rows[suspended.id].css('[data-badge="suspended"]')).not_to be_empty
      expect(rows[older.id].css('[data-badge]')).to be_empty
    end

    it 'shows which services each person has linked' do
      user = create(:user, username: 'linked')
      create(:identity, user: user, provider: 'twitch', uuid: 't')
      create(:identity, user: user, provider: 'github', uuid: 'g')

      get admin_users_path

      row = html.at_css("tr[data-user-id='#{user.id}']")
      expect(row.text).to include('Twitch').and include('GitHub')
    end

    it 'searches by username, email or name' do
      create(:user, username: 'findme', email: 'x@example.com', firstname: 'Zed', lastname: 'Zebra')
      create(:user, username: 'other', email: 'other@example.com')

      get admin_users_path, params: { q: 'FINDME' }
      expect(usernames).to eq(['findme'])

      get admin_users_path, params: { q: 'zebra' }
      expect(usernames).to eq(['findme'])

      get admin_users_path, params: { q: 'other@' }
      expect(usernames).to eq(['other'])
    end

    it 'says so when nothing matches' do
      get admin_users_path, params: { q: 'no-such-person' }
      expect(usernames).to be_empty
      expect(html.at_css('[data-pagination]').text).to include('No users')
    end

    it 'filters by role' do
      create(:user, username: 'plain')
      get admin_users_path, params: { role: 'admin' }
      expect(usernames).to eq(['rootadmin'])

      get admin_users_path, params: { role: 'regular' }
      expect(usernames).to eq(['plain'])
    end

    it 'filters by status' do
      create(:user, username: 'banned').suspend!
      get admin_users_path, params: { status: 'suspended' }
      expect(usernames).to eq(['banned'])

      get admin_users_path, params: { status: 'active' }
      expect(usernames).to eq(['rootadmin'])
    end

    it 'filters by linked service' do
      create(:identity, user: create(:user, username: 'streamer'), provider: 'twitch', uuid: 't')
      create(:user, username: 'nobody')

      get admin_users_path, params: { provider: 'twitch' }
      expect(usernames).to eq(['streamer'])
    end

    it 'sorts' do
      create(:user, username: 'aaa', created_at: 5.days.ago)
      get admin_users_path, params: { sort: 'username' }
      expect(usernames).to eq(%w[aaa rootadmin])

      get admin_users_path, params: { sort: 'oldest' }
      expect(usernames.first).to eq('aaa')
    end

    it 'ignores filter and sort values it does not recognise instead of failing' do
      create(:user, username: 'plain')

      get admin_users_path, params: { role: 'god', status: 'x', provider: "'; DROP TABLE users;--", sort: 'password_digest' }

      expect(response).to have_http_status(:success)
      expect(usernames).to match_array(%w[rootadmin plain])
    end

    it 'keeps the chosen filters selected in the form' do
      get admin_users_path, params: { q: 'abc', role: 'admin', status: 'active', provider: 'github', sort: 'oldest' }

      expect(html.at_css('input[name="q"]')['value']).to eq('abc')
      expect(html.at_css('select[name="role"] option[selected]')['value']).to eq('admin')
      expect(html.at_css('select[name="provider"] option[selected]')['value']).to eq('github')
      expect(html.at_css('select[name="sort"] option[selected]')['value']).to eq('oldest')
    end

    describe 'pagination' do
      before { create_list(:user, 30) } # 31 users with the admin

      it 'shows 25 at a time, with a link to the next page that keeps the filters' do
        get admin_users_path, params: { sort: 'oldest' }

        expect(html.css('tr[data-user-id]').size).to eq(25)
        expect(html.at_css('[data-pagination]').text).to include('1–25 of 31')
        next_href = html.at_css('a[rel="next"]')['href']
        expect(Rack::Utils.parse_query(URI(next_href).query)).to include('page' => '2', 'sort' => 'oldest')
        expect(html.at_css('a[rel="prev"]')).to be_nil
      end

      it 'shows the rest on the second page' do
        get admin_users_path, params: { page: 2 }

        expect(html.css('tr[data-user-id]').size).to eq(6)
        expect(html.at_css('[data-pagination]').text).to include('26–31 of 31')
        expect(html.at_css('a[rel="next"]')).to be_nil
        expect(html.at_css('a[rel="prev"]')).to be_present
      end

      it 'treats a page number that is out of range as the nearest real page' do
        get admin_users_path, params: { page: 99 }
        expect(html.at_css('[data-pagination]').text).to include('26–31 of 31')

        get admin_users_path, params: { page: -4 }
        expect(html.at_css('[data-pagination]').text).to include('1–25 of 31')

        get admin_users_path, params: { page: 'abc' }
        expect(response).to have_http_status(:success)
      end
    end
  end

  describe 'GET /admin/users/:id' do
    let(:user) { create(:user, username: 'subject', email: 'subject@example.com', firstname: 'Sub', lastname: 'Ject') }

    it "shows the person's details and linked accounts, with a link to each service profile" do
      create(:identity, user: user, provider: 'twitch', uuid: 't', username: 'subject_tv')
      create(:identity, user: user, provider: 'youtube', uuid: 'y', username: 'SubjectYT')

      get admin_user_path(user)

      expect(response).to have_http_status(:success)
      expect(html.text).to include('subject@example.com').and include('Sub Ject')
      rows = html.css('[data-identities] tr[data-identity-id]')
      expect(rows.map { |r| r.at_css('td').text }).to eq(%w[Twitch YouTube])
      expect(html.at_css('a[href="https://www.twitch.tv/subject_tv"]')).to be_present
      expect(html.at_css('a[href="https://www.youtube.com/@SubjectYT"]')).to be_present
    end

    it 'says when someone has no linked accounts' do
      get admin_user_path(user)
      expect(html.text).to include('signs in with email and password')
    end

    it 'shows why a suspended user was suspended' do
      user.suspend!(reason: 'Harassment in chat')
      get admin_user_path(user)

      banner = html.at_css('[data-suspension]')
      expect(banner.text).to include('Harassment in chat')
      expect(html.text).to include('Restore access')
      expect(html.text).not_to include('Reason (shown to them')
    end

    it 'shows the admin activity concerning this user' do
      AuditLog.record(actor: admin, action: 'user.updated', target: user, details: { changes: { 'email' => ['a@x.com', 'b@x.com'] } })

      get admin_user_path(user)

      activity = html.at_css('[data-activity]').text
      expect(activity).to include('Edited a user').and include('email: a@x.com → b@x.com').and include('rootadmin')
    end

    it 'offers every action for another user' do
      get admin_user_path(user)

      expect(html.at_css("form[action='#{grant_admin_admin_user_path(user)}']")).to be_present
      expect(html.at_css("form[action='#{suspend_admin_user_path(user)}']")).to be_present
      expect(html.at_css("form[action='#{send_password_reset_admin_user_path(user)}']")).to be_present
      expect(html.at_css("form[action='#{admin_user_path(user)}'] input[name='_method'][value='delete']")).to be_present
    end

    it "hides the password reset for someone who hasn't given a real email yet" do
      user.update_columns(email: 'pending-abc@users.mutter.local')
      get admin_user_path(user)
      expect(html.at_css("form[action='#{send_password_reset_admin_user_path(user)}']")).to be_nil
    end

    it "doesn't offer an admin the actions they could use to lock themselves out" do
      get admin_user_path(admin)

      expect(html.text).to include('This is you')
      expect(html.at_css("form[action='#{revoke_admin_admin_user_path(admin)}']")).to be_nil
      expect(html.at_css("form[action='#{suspend_admin_user_path(admin)}']")).to be_nil
      expect(html.at_css("form[action='#{admin_user_path(admin)}'] input[name='_method'][value='delete']")).to be_nil
    end

    it 'is a 404 for a user that does not exist' do
      get admin_user_path(id: 0)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'PATCH /admin/users/:id' do
    let(:user) { create(:user, username: 'before', email: 'before@example.com', firstname: 'Bea', lastname: 'Fore') }

    it "updates the person's profile and records exactly what changed" do
      patch admin_user_path(user), params: { user: { username: 'after', email: 'After@Example.com', firstname: 'Bea' } }

      expect(response).to redirect_to(admin_user_path(user))
      expect(user.reload).to have_attributes(username: 'after', email: 'after@example.com', firstname: 'Bea')
      expect(latest_audit).to have_attributes(action: 'user.updated', actor: admin, target_id: user.id)
      expect(latest_audit.details['changes']).to eq('username' => %w[before after], 'email' => ['before@example.com', 'after@example.com'])
    end

    it "doesn't log anything when nothing changed" do
      expect do
        patch admin_user_path(user), params: { user: { username: 'before' } }
      end.not_to change(AuditLog, :count)
      expect(response).to redirect_to(admin_user_path(user))
    end

    it 'explains what is wrong, and changes nothing, when the new values are invalid' do
      create(:user, username: 'taken')

      expect do
        patch admin_user_path(user), params: { user: { username: 'TAKEN', email: 'new@example.com' } }
      end.not_to change(AuditLog, :count)

      expect(response).to have_http_status(422)
      expect(html.at_css('[data-form-errors]').text).to match(/username/i)
      expect(user.reload).to have_attributes(username: 'before', email: 'before@example.com')
    end

    it 'cannot be used to grant admin, change the password or suspend someone' do
      patch admin_user_path(user), params: { user: { admin: true, password: 'hacked123', password_confirmation: 'hacked123', suspended_at: Time.current, firstname: 'Ok' } }

      user.reload
      expect(user.firstname).to eq('Ok')
      expect(user).not_to be_admin
      expect(user).not_to be_suspended
      expect(user.authenticate('password123')).to be_truthy
    end
  end

  describe 'PATCH /admin/users/:id/grant_admin and revoke_admin' do
    let(:user) { create(:user) }

    it 'makes someone an admin, and records it' do
      patch grant_admin_admin_user_path(user)

      expect(response).to redirect_to(admin_user_path(user))
      expect(user.reload).to be_admin
      expect(latest_audit).to have_attributes(action: 'user.admin_granted', actor: admin, target_id: user.id)
    end

    it 'does not log a second grant for someone who is already an admin' do
      user.update!(admin: true)
      expect { patch grant_admin_admin_user_path(user) }.not_to change(AuditLog, :count)
      expect(flash[:notice]).to match(/already an admin/)
    end

    it 'removes admin rights, and records it' do
      user.update!(admin: true)
      patch revoke_admin_admin_user_path(user)

      expect(user.reload).not_to be_admin
      expect(latest_audit).to have_attributes(action: 'user.admin_revoked', target_id: user.id)
    end

    it 'takes effect on their very next request' do
      other = create(:user, :admin)
      delete session_path
      sign_in_as(other)
      get admin_users_path
      expect(response).to have_http_status(:success)

      other.update!(admin: false)
      get admin_users_path
      expect(response).to have_http_status(:not_found)
    end

    it "won't let an admin remove their own admin rights" do
      expect { patch revoke_admin_admin_user_path(admin) }.not_to change(AuditLog, :count)

      expect(admin.reload).to be_admin
      expect(flash[:alert]).to match(/your own account/)
    end
  end

  describe 'PATCH /admin/users/:id/suspend and unsuspend' do
    let(:user) { create(:user) }

    it 'suspends with a reason, and records it' do
      patch suspend_admin_user_path(user), params: { reason: 'Ban evasion' }

      expect(user.reload).to be_suspended
      expect(user.suspension_reason).to eq('Ban evasion')
      expect(latest_audit).to have_attributes(action: 'user.suspended', target_id: user.id)
      expect(latest_audit.details).to eq('reason' => 'Ban evasion')
    end

    it 'suspends with no reason' do
      patch suspend_admin_user_path(user)
      expect(user.reload).to be_suspended
      expect(latest_audit.details).to eq({})
    end

    it 'refuses an over-long reason and leaves the person active' do
      expect { patch suspend_admin_user_path(user), params: { reason: 'x' * 501 } }.not_to change(AuditLog, :count)

      expect(user.reload).not_to be_suspended
      expect(flash[:alert]).to match(/Couldn't suspend/)
    end

    it "doesn't log a second suspension" do
      user.suspend!
      expect { patch suspend_admin_user_path(user) }.not_to change(AuditLog, :count)
    end

    it 'can suspend another admin' do
      other = create(:user, :admin)
      patch suspend_admin_user_path(other)
      expect(other.reload).to be_suspended
    end

    it "won't let an admin suspend themselves" do
      expect { patch suspend_admin_user_path(admin) }.not_to change(AuditLog, :count)
      expect(admin.reload).not_to be_suspended
    end

    it 'restores access, and records it' do
      user.suspend!(reason: 'x')
      patch unsuspend_admin_user_path(user)

      expect(user.reload).not_to be_suspended
      expect(user.suspension_reason).to be_nil
      expect(latest_audit).to have_attributes(action: 'user.unsuspended', target_id: user.id)
    end

    it "doesn't log a restore for someone who isn't suspended" do
      expect { patch unsuspend_admin_user_path(user) }.not_to change(AuditLog, :count)
    end
  end

  describe 'DELETE /admin/users/:id' do
    let!(:user) { create(:user, username: 'goner', email: 'goner@example.com') }

    it 'deletes the user and everything that belongs to them, and keeps a record of who they were' do
      create(:identity, user: user, provider: 'github', uuid: 'g')
      account = create(:twitter_account, user: user)
      create(:tweet, user: user, twitter_account: account)

      expect { delete admin_user_path(user) }
        .to change(User, :count).by(-1).and change(Identity, :count).by(-1)
        .and change(TwitterAccount, :count).by(-1).and change(Tweet, :count).by(-1)

      expect(response).to redirect_to(admin_users_path)
      expect(latest_audit).to have_attributes(action: 'user.deleted', actor: admin, target_label: 'goner <goner@example.com>')
    end

    it "won't let an admin delete themselves" do
      expect { delete admin_user_path(admin) }.not_to change(User, :count)
      expect(flash[:alert]).to match(/your own account/)
    end

    it 'keeps earlier history about the deleted user readable' do
      AuditLog.record(actor: admin, action: 'user.suspended', target: user)
      delete admin_user_path(user)

      get admin_audit_logs_path
      expect(html.text).to include('goner <goner@example.com>')
    end
  end

  describe 'POST /admin/users/:id/send_password_reset' do
    let(:user) { create(:user, email: 'reset-me@example.com') }

    it 'emails the person a reset link, and records it' do
      expect { post send_password_reset_admin_user_path(user) }.to change { ActionMailer::Base.deliveries.size }.by(1)

      mail = ActionMailer::Base.deliveries.last
      expect(mail.to).to eq(['reset-me@example.com'])
      expect(mail.body.encoded).to include('password_reset')
      expect(latest_audit).to have_attributes(action: 'user.password_reset_sent', target_id: user.id)
      expect(flash[:notice]).to include('reset-me@example.com')
    end

    it "won't email a placeholder address" do
      user.update_columns(email: 'pending-abc@users.mutter.local')

      expect { post send_password_reset_admin_user_path(user) }.not_to(change { ActionMailer::Base.deliveries.size })
      expect(flash[:alert]).to match(/no real email/)
      expect(AuditLog.count).to eq(0)
    end

    it 'reports a mail failure instead of crashing, and does not claim it was sent' do
      allow(PasswordMailer).to receive(:with).and_raise(Errno::ECONNREFUSED)

      post send_password_reset_admin_user_path(user)

      expect(response).to redirect_to(admin_user_path(user))
      expect(flash[:alert]).to match(/couldn't be sent/)
      expect(AuditLog.count).to eq(0)
    end
  end
end
