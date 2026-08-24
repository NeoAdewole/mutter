FactoryBot.define do
  factory :twitter_account do
    user
    name { Faker::Internet.username }
    sequence(:username) { |n| "twitter_user#{n}" }
    image { Faker::Internet.url }
    token { SecureRandom.hex(20) }
    secret { SecureRandom.hex(20) }
  end
end
