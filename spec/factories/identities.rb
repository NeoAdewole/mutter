FactoryBot.define do
  factory :identity do
    user
    provider { 'github' }
    sequence(:uuid) { |n| "uuid-#{n}" }
  end
end
