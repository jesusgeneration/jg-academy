FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "person#{n}@example.com" }
    password { "sup3rsecret!" }
    password_confirmation { "sup3rsecret!" }
    confirmed_at { Time.current }
    role { :user }
    locale { "de" }

    trait :unconfirmed do
      confirmed_at { nil }
    end

    trait :admin do
      role { :admin }
    end
  end

  factory :organization do
    sequence(:name) { |n| "St. Martin's #{n}" }
    description { "A cooperating church." }
  end

  factory :organization_membership do
    user
    organization
    role { :member }

    trait :organiser do
      role { :organiser }
    end
  end

  factory :content do
    sequence(:title) { |n| "Content #{n}" }
    content_type { :level }
    position { 0 }

    trait :level do
      content_type { :level }
      parent { nil }
    end

    trait :section do
      content_type { :section }
      association :parent, factory: [ :content, :level ]
    end

    trait :detail do
      content_type { :detail }
      association :parent, factory: [ :content, :section ]
    end
  end

  factory :program do
    association :organization
    sequence(:name) { |n| "Program #{n}" }
    description { "A training program." }
    kind { :schooling }

    trait :freizeit do
      kind { :freizeit }
    end
  end

  factory :unit_coverage do
    association :unit
    association :content, :detail
  end

  factory :unit do
    association :program
    sequence(:name) { |n| "Training Unit #{n}" }
    starts_at { 2.weeks.from_now.beginning_of_day + 18.hours }
    ends_at { starts_at ? starts_at + 2.days : 3.weeks.from_now }
    location { "Parish Hall" }
    description { nil }

    trait :past do
      starts_at { 1.month.ago }
      ends_at { 1.month.ago + 2.days }
    end
  end

  factory :unit_attendance do
    association :unit
    user
    status { :registered }

    trait :attended do
      status { :attended }
    end

    trait :cancelled do
      status { :cancelled }
    end

    trait :no_show do
      status { :no_show }
    end
  end
end
