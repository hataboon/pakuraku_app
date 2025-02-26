# app/controllers/concerns/meal_time_converter.rb
module MealTimeConverter
  def meal_time_to_japanese(meal_time)
    case meal_time.to_s.downcase
    when "morning" then "朝食"
    when "afternoon" then "昼食"
    when "evening" then "夕食"
    else "食事"
    end
  end
end
