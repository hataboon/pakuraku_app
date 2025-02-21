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

  # 日本語の表示名を取得するメソッドを追加
  def meal_time_display
    # read_attributeで直接データベース値を取得
    raw_value = read_attribute("meal_time")
    case raw_value
    when "0" then "朝食"
    when "1" then "昼食"
    when "2" then "夕食"
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

  # 関連付けを検索可能にする
  def self.ransackable_associations(auth_object = nil)
    [ "recipe", "user" ]
  end
end
