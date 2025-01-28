# app/models/concerns/meal_time_converter.rb
module MealTimeConverter
  extend ActiveSupport::Concern

  # 食事時間を日本語に変換するメソッド
  def meal_time_to_japanese(meal_time)
    time_mappings = {
      "morning" => "朝食",
      "afternoon" => "昼食",
      "evening" => "夕食"
    }

    # マッピングにない値の場合は'食事'をデフォルトとして返す
    time_mappings[meal_time.to_s.downcase] || "食事"
  end
end
