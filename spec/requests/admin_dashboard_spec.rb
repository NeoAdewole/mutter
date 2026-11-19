require 'rails_helper'

RSpec.describe 'Admin dashboard', type: :request do
  let(:admin) { create(:user, :admin, username: 'boss') }

  before { sign_in_as(admin) }

  def stat(key)
    html.at_css("[data-stat='#{key}'] dd").text.to_i
  end

  it 'is the landing page of the admin area, with tabs to every admin section' do
    get admin_root_path

    expect(response).to have_http_status(:success)
    expect(html.at_css('h1').text).to eq('Admin dashboard')
    tabs = html.css('nav[aria-label="Admin"] a').to_h { |a| [a.text, a['href']] }
    expect(tabs).to eq(
      'Dashboard' => admin_root_path, 'Pages' => admin_pages_path, 'Users' => admin_users_path,
      'Audit log' => admin_audit_logs_path, 'Settings' => admin_settings_path, 'System' => admin_system_path
    )
  end

  it 'marks the tab you are on' do
    get admin_users_path
    current = html.css('nav[aria-label="Admin"] a[aria-current="page"]')
    expect(current.map(&:text)).to eq(['Users'])

    get admin_root_path
    expect(html.css('nav[aria-label="Admin"] a[aria-current="page"]').map(&:text)).to eq(['Dashboard'])
  end

  it 'counts users: total, new, recently active, admins, suspended and without a real email' do
    create(:user, created_at: 3.days.ago, last_sign_in_at: 2.days.ago)
    create(:user, created_at: 20.days.ago)
    create(:user, created_at: 90.days.ago).suspend!
    create(:user, email: 'pending-x@users.mutter.local')
    admin.update!(last_sign_in_at: 1.hour.ago)

    get admin_root_path

    expect(stat('total')).to eq(5)
    expect(stat('new-week')).to eq(3) # the admin, the 3-day-old user and the placeholder user
    expect(stat('new-month')).to eq(4)
    expect(stat('active-week')).to eq(2)
    expect(stat('admins')).to eq(1)
    expect(stat('suspended')).to eq(1)
    expect(stat('missing-email')).to eq(1)
  end

  it 'links the counts to the matching, filtered user list' do
    get admin_root_path
    expect(html.at_css("[data-stat='admins'] a")['href']).to eq(admin_users_path(role: 'admin'))
    expect(html.at_css("[data-stat='suspended'] a")['href']).to eq(admin_users_path(status: 'suspended'))
  end

  it 'shows sign-ups for each of the last 14 days, including quiet ones' do
    travel_to(Time.zone.local(2026, 11, 18, 12)) do
      admin.update_columns(created_at: 40.days.ago)
      create(:user, created_at: Time.zone.local(2026, 11, 18, 9))
      create(:user, created_at: Time.zone.local(2026, 11, 18, 10))
      create(:user, created_at: Time.zone.local(2026, 11, 16, 10))
      create(:user, created_at: Time.zone.local(2026, 10, 1)) # outside the window

      get admin_root_path
    end

    rows = html.css('[data-signups] tbody tr').map { |row| row.css('td').first(2).map(&:text) }
    expect(rows.size).to eq(14)
    expect(rows.first).to eq(['Wed 18 Nov', '2'])
    expect(rows[1]).to eq(['Tue 17 Nov', '0'])
    expect(rows[2]).to eq(['Mon 16 Nov', '1'])
    expect(rows.sum { |_, count| count.to_i }).to eq(3)
  end

  it 'counts linked accounts per service, biggest first' do
    3.times { |i| create(:identity, provider: 'twitch', uuid: "t#{i}") }
    create(:identity, provider: 'github', uuid: 'g')

    get admin_root_path

    rows = html.css('[data-connections] tbody tr').map { |row| row.css('td').map(&:text) }
    expect(rows).to eq([%w[Twitch 3], %w[GitHub 1]])
  end

  it 'says so when nothing is linked yet' do
    get admin_root_path
    expect(html.at_css('[data-connections]')).to be_nil
    expect(html.text).to include('Nobody has linked a provider account yet')
  end

  it 'counts published pages and drafts in each section' do
    create(:page, :published, section: 'gaming', title: 'A')
    create(:page, :published, section: 'gaming', title: 'B')
    create(:page, :draft, section: 'gaming', title: 'C')

    get admin_root_path

    rows = html.css('[data-pages] tbody tr').to_h do |row|
      cells = row.css('td').map(&:text)
      [cells[0], cells[1..].map(&:to_i)]
    end
    expect(rows).to eq('Streaming' => [0, 0], 'Content' => [0, 0], 'Gaming' => [2, 1], 'Community' => [0, 0])
  end

  it 'lists the newest users and recent admin activity' do
    create(:user, username: 'fresh')
    AuditLog.record(actor: admin, action: 'user.suspended', target: create(:user, username: 'victim'))

    get admin_root_path

    expect(html.at_css('[data-recent-users]').text).to include('fresh')
    activity = html.at_css('[data-recent-activity]').text
    expect(activity).to include('boss').and include('Suspended a user').and include('victim')
  end

  it 'invites the first action when there is no activity yet' do
    get admin_root_path
    expect(html.text).to include('Actions admins take are recorded here')
  end

  it 'is reachable from the site navigation for admins only' do
    get root_path
    expect(html.css("nav a[href='#{admin_root_path}']")).not_to be_empty

    delete session_path
    sign_in_as(create(:user))
    get root_path
    expect(html.css("nav a[href='#{admin_root_path}']")).to be_empty
  end
end
