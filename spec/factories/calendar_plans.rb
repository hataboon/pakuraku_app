FactoryBot.define do
  factory :calendar_plan do
    recipe
    user
    date { Date.current }
    meal_time { "morning" }
  end
end