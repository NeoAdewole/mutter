FactoryBot.define do
  factory :page_block do
    page { association :page, :published }
    kind { 'text' }

    trait :text do
      kind { 'text' }
      body { 'Some **text**.' }
    end

    trait :carousel do
      kind { 'carousel' }
    end

    trait :cards do
      kind { 'cards' }
      columns { 3 }
    end
  end

  factory :block_item do
    block { association :page_block, :cards }
    sequence(:title) { |n| "Card #{n}" }

    trait :slide do
      block { association :page_block, :carousel }
      title { '' }
      sequence(:image_url) { |n| "https://images.example.com/banner-#{n}.jpg" }
      sequence(:alt_text) { |n| "Banner #{n}" }
    end
  end
end
