require 'rails_helper'

RSpec.describe Tweet, type: :model do
  subject(:tweet) { build(:tweet) }

  describe 'associations' do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:twitter_account) }
  end

  describe 'validations' do
    it { is_expected.to validate_length_of(:body).is_at_least(1).is_at_most(280) }
    it { is_expected.to validate_presence_of(:publish_at) }
  end

  describe 'defaults' do
    it 'defaults publish_at to 24 hours from now when not set' do
      freeze_time do
        tweet = Tweet.new
        expect(tweet.publish_at).to eq(24.hours.from_now)
      end
    end

    it 'does not override an explicitly set publish_at' do
      scheduled = 3.days.from_now
      tweet = Tweet.new(publish_at: scheduled)
      expect(tweet.publish_at).to be_within(1.second).of(scheduled)
    end
  end

  describe '#published?' do
    it 'is false when tweet_id is absent' do
      expect(build(:tweet, tweet_id: nil)).not_to be_published
    end

    it 'is true once tweet_id is present' do
      expect(build(:tweet, :published)).to be_published
    end
  end

  describe 'scopes' do
    let!(:pending_tweet) { create(:tweet, tweet_id: nil) }
    let!(:published_tweet) { create(:tweet, :published) }

    describe '.pending' do
      it 'returns only tweets without a tweet_id' do
        expect(Tweet.pending).to contain_exactly(pending_tweet)
      end
    end

    describe '.published' do
      it 'returns only tweets with a tweet_id' do
        expect(Tweet.published).to contain_exactly(published_tweet)
      end
    end
  end
end
