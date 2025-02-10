FactoryBot.define do
  factory :food do
    recipe
    name { Faker::Food.ingredient }
  end
end