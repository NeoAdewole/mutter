FactoryBot.define do
  factory :page do
    section { 'content' }
    sequence(:title) { |n| "Page #{n}" }
    body { 'Some **body** text.' }
    published { false }

    trait :published do
      published { true }
    end

    trait :draft do
      published { false }
    end
  end
end
