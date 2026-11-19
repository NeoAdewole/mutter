require 'rails_helper'

RSpec.describe AuditLog, type: :model do
  let(:admin) { create(:user, :admin, username: 'boss', email: 'boss@example.com') }
  let(:target) { create(:user, username: 'target', email: 'target@example.com') }

  describe '.record' do
    it 'stores who did what to whom, with readable labels' do
      entry = described_class.record(actor: admin, action: 'user.suspended', target: target,
                                     details: { reason: 'spam' }, ip_address: '203.0.113.9')

      entry = described_class.find(entry.id)
      expect(entry.actor).to eq(admin)
      expect(entry.actor_label).to eq('boss <boss@example.com>')
      expect(entry.target_type).to eq('User')
      expect(entry.target_id).to eq(target.id)
      expect(entry.target_label).to eq('target <target@example.com>')
      expect(entry.details).to eq('reason' => 'spam')
      expect(entry.ip_address).to eq('203.0.113.9')
      expect(entry.summary).to eq('Suspended a user')
    end

    it 'works with no target (for example a settings change)' do
      entry = described_class.record(actor: admin, action: 'settings.updated', details: { changes: { 'a' => [1, 2] } })
      expect(entry.target_type).to be_nil
      expect(entry.target_label).to be_nil
    end

    it 'labels a page by its section and title' do
      page = create(:page, section: 'gaming', title: 'Reviews')
      entry = described_class.record(actor: admin, action: 'page.created', target: page)
      expect(entry.target_label).to eq('Gaming: Reviews')
    end

    it 'refuses an action it does not know about' do
      expect { described_class.record(actor: admin, action: 'made.up') }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end

  describe 'as a permanent record' do
    let!(:entry) { described_class.record(actor: admin, action: 'user.deleted', target: target) }

    it 'cannot be edited' do
      expect { described_class.find(entry.id).update!(action: 'user.updated') }.to raise_error(ActiveRecord::ReadOnlyRecord)
    end

    it 'cannot be deleted' do
      expect { described_class.find(entry.id).destroy }.to raise_error(ActiveRecord::ReadOnlyRecord)
    end

    it 'keeps the admin name, and the entry, after the admin is deleted' do
      admin.destroy!

      kept = described_class.find(entry.id)
      expect(kept.actor).to be_nil
      expect(kept.actor_label).to eq('boss <boss@example.com>')
    end

    it 'keeps the target name after the target is deleted' do
      target.destroy!
      expect(described_class.find(entry.id).target_label).to eq('target <target@example.com>')
    end
  end

  describe 'scopes' do
    it 'lists newest first' do
      older = described_class.record(actor: admin, action: 'settings.updated')
      newer = described_class.record(actor: admin, action: 'system.cache_cleared')
      older.class.where(id: older.id).update_all(created_at: 2.days.ago)

      expect(described_class.newest_first).to eq([newer, older])
    end

    it 'finds entries involving a user, as the target or as the admin who acted' do
      about_target = described_class.record(actor: admin, action: 'user.suspended', target: target)
      by_admin = described_class.record(actor: admin, action: 'settings.updated')
      other = described_class.record(actor: create(:user, :admin), action: 'user.suspended', target: create(:user))

      expect(described_class.involving(target)).to contain_exactly(about_target)
      expect(described_class.involving(admin)).to contain_exactly(about_target, by_admin)
      expect(described_class.involving(target)).not_to include(other)
    end
  end

  it 'describes every action it can record' do
    expect(described_class::ACTIONS.values).to all(be_present)
  end
end
