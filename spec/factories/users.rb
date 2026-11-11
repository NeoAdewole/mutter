FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    sequence(:username) { |n| "user#{n}" }
    firstname { Faker::Name.first_name }
    lastname { Faker::Name.last_name }
    password { 'password123' }
    password_confirmation { 'password123' }
  end
end
