FactoryBot.define do
  factory :recipe do
    name { Faker::Food.dish }
  end
end
