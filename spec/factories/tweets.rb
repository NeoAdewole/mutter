FactoryBot.define do
  factory :tweet do
    user
    twitter_account
    body { Faker::Lorem.sentence(word_count: 10) }
    publish_at { 1.hour.from_now }

    trait :published do
      tweet_id { SecureRandom.hex(9) }
    end
  end
end
