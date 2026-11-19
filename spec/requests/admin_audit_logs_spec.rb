require 'rails_helper'

RSpec.describe 'Admin audit log', type: :request do
  let(:admin) { create(:user, :admin, username: 'boss', email: 'boss@example.com') }
  let(:other_admin) { create(:user, :admin, username: 'deputy', email: 'deputy@example.com') }

  before { sign_in_as(admin) }

  def rows
    html.css('[data-audit-table] tbody tr')
  end

  it 'says when nothing has happened yet' do
    get admin_audit_logs_path
    expect(response).to have_http_status(:success)
    expect(rows).to be_empty
    expect(html.at_css('[data-pagination]').text).to include('No entries')
  end

  it 'lists entries newest first with who, what and the details' do
    target = create(:user, username: 'subject', email: 'subject@example.com')
    AuditLog.record(actor: other_admin, action: 'user.updated', target: target,
                    details: { changes: { 'email' => ['old@example.com', 'new@example.com'] } }, ip_address: '203.0.113.7')
    newest = AuditLog.record(actor: admin, action: 'user.suspended', target: target, details: { reason: 'spam' })

    get admin_audit_logs_path

    expect(rows.map { |row| row['data-audit-action'] }).to eq(%w[user.suspended user.updated])
    first, second = rows.map(&:text)
    expect(first).to include('boss <boss@example.com>').and include('Suspended a user').and include('reason: spam')
    expect(second).to include('deputy <deputy@example.com>').and include('email: old@example.com → new@example.com')
    expect(second).to include('203.0.113.7')
    expect(first).to include('subject <subject@example.com>')
    expect(newest).to be_persisted
  end

  it 'shows a setting change by the setting name, not its internal key' do
    AuditLog.record(actor: admin, action: 'settings.updated', details: { changes: { 'signups_enabled' => [true, false] } })

    get admin_audit_logs_path

    expect(rows.first.text).to include('Allow new sign-ups: true → false')
  end

  it 'filters by action' do
    AuditLog.record(actor: admin, action: 'user.suspended')
    AuditLog.record(actor: admin, action: 'page.created')

    get admin_audit_logs_path, params: { action_filter: 'page.created' }

    expect(rows.map { |row| row['data-audit-action'] }).to eq(['page.created'])
  end

  it 'filters by the admin or the subject' do
    AuditLog.record(actor: admin, action: 'user.suspended', target: create(:user, username: 'alpha', email: 'alpha@example.com'))
    AuditLog.record(actor: other_admin, action: 'user.updated', target: create(:user, username: 'beta', email: 'beta@example.com'))

    get admin_audit_logs_path, params: { q: 'deputy' }
    expect(rows.size).to eq(1)
    expect(rows.first.text).to include('deputy')

    get admin_audit_logs_path, params: { q: 'ALPHA' }
    expect(rows.size).to eq(1)
    expect(rows.first.text).to include('alpha')
  end

  it 'filters by how recent' do
    old = AuditLog.record(actor: admin, action: 'user.suspended')
    AuditLog.where(id: old.id).update_all(created_at: 10.days.ago)
    AuditLog.record(actor: admin, action: 'user.updated')

    get admin_audit_logs_path, params: { period: '7d' }
    expect(rows.map { |row| row['data-audit-action'] }).to eq(['user.updated'])

    get admin_audit_logs_path, params: { period: '30d' }
    expect(rows.size).to eq(2)
  end

  it 'ignores filter values it does not recognise' do
    AuditLog.record(actor: admin, action: 'user.suspended')

    get admin_audit_logs_path, params: { action_filter: "x' OR 1=1 --", period: 'forever' }

    expect(response).to have_http_status(:success)
    expect(rows.size).to eq(1)
  end

  it 'treats LIKE wildcards in the search literally' do
    AuditLog.record(actor: admin, action: 'user.suspended')
    get admin_audit_logs_path, params: { q: '%' }
    expect(rows).to be_empty
  end

  it 'pages through long histories 50 at a time' do
    55.times { AuditLog.record(actor: admin, action: 'system.cache_cleared') }

    get admin_audit_logs_path
    expect(rows.size).to eq(50)
    expect(html.at_css('a[rel="next"]')).to be_present

    get admin_audit_logs_path, params: { page: 2 }
    expect(rows.size).to eq(5)
  end

  it 'labels entries from an admin who has since been deleted' do
    gone = create(:user, :admin, username: 'gone', email: 'gone@example.com')
    AuditLog.record(actor: gone, action: 'settings.updated')
    gone.destroy!

    get admin_audit_logs_path

    expect(rows.first.text).to include('gone <gone@example.com>')
  end

  it 'has no way to edit or delete an entry' do
    entry = AuditLog.record(actor: admin, action: 'settings.updated')

    delete "/admin/audit_logs/#{entry.id}"
    expect(response).to have_http_status(:not_found)
    patch "/admin/audit_logs/#{entry.id}", params: { audit_log: { action: 'user.updated' } }
    expect(response).to have_http_status(:not_found)
    expect(entry.reload.action).to eq('settings.updated')
    expect(AuditLog.count).to eq(1)
  end
end
