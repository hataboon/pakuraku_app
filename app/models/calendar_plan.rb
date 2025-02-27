class CalendarPlan < ApplicationRecord
  belongs_to :user
  belongs_to :recipe, optional: true

  enum :meal_time, {
    morning: 0,
    afternoon: 1,
    evening: 2
  }
  validates :date, presence: true
  validates :meal_time, presence: true

  def meal_time_i18n
    I18n.t("enums.calendar_plan.meal_time.#{meal_time}")
  end

  def meal_time_text
    case meal_time.to_s
    when "", "nil" then "設定なし"
    when "0", "0.0", "morning" then "朝食"
    when "1", "1.0", "afternoon" then "昼食"
    when "2", "2.0", "evening" then "夕食"
    else "設定なし"
    end
  end

  def self.meal_time_mappings
    {
      "0" => "朝食",
      "1" => "昼食",
      "2" => "夕食"
    }
  end

  def self.ransackable_attributes(auth_object = nil)
    %w[created_at date id meal_plan meal_time user_id]
  end

  def self.ransackable_associations(auth_object = nil)
    [ "recipe", "user" ]
  end
end
