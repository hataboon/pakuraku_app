# app/helpers/nutritions_helper.rb
module NutritionsHelper
  # 栄養素のスコアを計算するメソッド
  def calculate_nutrient_score(nutrient_str)
    return 0 if nutrient_str.blank?
    count = nutrient_str.split(",").size
    [ count * 33, 100 ].min
  end

  # デフォルトの栄養素情報
  DEFAULT_NUTRIENTS = {
    protein: "0g",
    fat: "0g",
    carbohydrates: "0g",
    vitamins: "データなし",
    minerals: "データなし"
  }.freeze

  # 栄養素情報を補完するメソッド
  def complete_nutrients(nutrients)
    DEFAULT_NUTRIENTS.merge(nutrients || {})
  end
end
