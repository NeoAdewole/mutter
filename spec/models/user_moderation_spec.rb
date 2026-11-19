require 'rails_helper'

RSpec.describe User, 'admin tooling', type: :model do
  describe '#suspend! / #unsuspend!' do
    it 'marks the account suspended, with the reason, and can undo it' do
      user = create(:user)
      expect(user).not_to be_suspended

      freeze_time do
        user.suspend!(reason: '  Spamming the chat  ')
        expect(user.reload).to be_suspended
        expect(user.suspended_at).to eq(Time.current)
        expect(user.suspension_reason).to eq('Spamming the chat')
      end

      user.unsuspend!
      expect(user.reload).not_to be_suspended
      expect(user.suspension_reason).to be_nil
    end

    it 'treats a blank reason as no reason' do
      user = create(:user)
      user.suspend!(reason: '   ')
      expect(user.reload.suspension_reason).to be_nil
    end

    it 'rejects an over-long reason' do
      user = create(:user)
      expect { user.suspend!(reason: 'x' * 501) }.to raise_error(ActiveRecord::RecordInvalid)
      expect(user.reload).not_to be_suspended
    end
  end

  describe 'scopes' do
    let!(:admin) { create(:user, :admin) }
    let!(:regular) { create(:user) }
    let!(:suspended) { create(:user).tap(&:suspend!) }

    it 'splits admins from regular users' do
      expect(described_class.admins).to contain_exactly(admin)
      expect(described_class.regular).to contain_exactly(regular, suspended)
    end

    it 'splits active from suspended accounts' do
      expect(described_class.suspended).to contain_exactly(suspended)
      expect(described_class.active).to contain_exactly(admin, regular)
    end

    it 'finds users by a linked provider' do
      create(:identity, user: regular, provider: 'twitch', uuid: 't1')
      create(:identity, user: admin, provider: 'github', uuid: 'g1')

      expect(described_class.with_provider('twitch')).to contain_exactly(regular)
    end
  end

  describe '.search' do
    let!(:ada) { create(:user, username: 'AdaL', email: 'ada@example.com', firstname: 'Ada', lastname: 'Lovelace') }
    let!(:bob) { create(:user, username: 'bobby', email: 'bob@example.org', firstname: 'Robert', lastname: 'Builder') }

    it 'matches username, email and name, ignoring case' do
      expect(described_class.search('adal')).to contain_exactly(ada)
      expect(described_class.search('EXAMPLE.ORG')).to contain_exactly(bob)
      expect(described_class.search('lovel')).to contain_exactly(ada)
      expect(described_class.search('robert')).to contain_exactly(bob)
    end

    it 'returns everyone for a blank term' do
      expect(described_class.search('  ')).to contain_exactly(ada, bob)
      expect(described_class.search(nil)).to contain_exactly(ada, bob)
    end

    it 'matches LIKE wildcards literally' do
      expect(described_class.search('%')).to be_empty
      expect(described_class.search('_')).to be_empty
    end
  end

  describe '.sorted_by' do
    it 'orders by the chosen key, and falls back to newest first for anything else' do
      old = create(:user, username: 'zed', created_at: 3.days.ago)
      new = create(:user, username: 'amy', created_at: 1.day.ago)

      expect(described_class.sorted_by('newest')).to eq([new, old])
      expect(described_class.sorted_by('oldest')).to eq([old, new])
      expect(described_class.sorted_by('username')).to eq([new, old])
      expect(described_class.sorted_by('1; DROP TABLE users')).to eq([new, old])
    end

    it 'puts people who have never signed in last when sorting by recent sign-in' do
      never = create(:user)
      recent = create(:user, last_sign_in_at: 1.hour.ago)
      earlier = create(:user, last_sign_in_at: 2.days.ago)

      expect(described_class.sorted_by('recent_sign_in')).to eq([recent, earlier, never])
    end
  end

  describe '#record_sign_in!' do
    it 'counts the sign-in and remembers when it happened' do
      user = create(:user)
      freeze_time do
        2.times { user.record_sign_in! }
        expect(user.reload.sign_in_count).to eq(2)
        expect(user.last_sign_in_at).to eq(Time.current)
      end
    end
  end

  describe '#placeholder_email?' do
    it 'is true only for the stand-in address given to accounts whose provider sent no email' do
      expect(build(:user, email: 'pending-abc123@users.mutter.local')).to be_placeholder_email
      expect(build(:user, email: 'real@example.com')).not_to be_placeholder_email
    end
  end

  describe '#can_sign_in_without?' do
    let(:user) { create(:user, password_set: false) }
    let!(:github) { create(:identity, user: user, provider: 'github', uuid: 'g') }

    it 'is false when the identity is the only way in' do
      expect(user.can_sign_in_without?(github)).to be(false)
    end

    it 'is true when the account has a password' do
      user.update!(password_set: true)
      expect(user.can_sign_in_without?(github)).to be(true)
    end

    it 'is true when another provider can still sign them in' do
      create(:identity, user: user, provider: 'twitch', uuid: 't')
      expect(user.can_sign_in_without?(github)).to be(true)
    end

    it "doesn't count a connect-only provider (YouTube) as a way in" do
      create(:identity, user: user, provider: 'youtube', uuid: 'y')
      expect(user.can_sign_in_without?(github)).to be(false)
    end
  end

  describe '.account_exists_for?' do
    def auth(uid:, email: nil)
      OmniAuth::AuthHash.new(provider: 'github', uid: uid, info: { email: email })
    end

    it 'is true for a provider identity that is already linked' do
      create(:identity, provider: 'github', uuid: 'known')
      expect(described_class.account_exists_for?(auth(uid: 'known'))).to be(true)
    end

    it 'is true when the email belongs to an existing account' do
      create(:user, email: 'someone@example.com')
      expect(described_class.account_exists_for?(auth(uid: 'new', email: 'Someone@Example.com'))).to be(true)
    end

    it 'is false for someone entirely new, with or without an email' do
      expect(described_class.account_exists_for?(auth(uid: 'new', email: 'fresh@example.com'))).to be(false)
      expect(described_class.account_exists_for?(auth(uid: 'new'))).to be(false)
    end
  end
end
