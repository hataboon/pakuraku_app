module NutritionsHelper
  # 栄養素の名称マッピング
  NUTRIENT_NAMES = {
    protein: "タンパク質",
    fat: "脂質",
    carbohydrates: "炭水化物",
    vitamins: "ビタミン",
    mineral: "ミネラル"
  }

  # 栄養素の翻訳
  def translate_nutrient(key)
    NUTRIENT_NAMES[key.to_sym] || key.to_s
  end

  # 栄養素の適量範囲を返す（公式基準に基づく）
  def nutrient_reference_ranges
    {
      protein: { low: [ 0, 10 ], medium: [ 11, 20 ], high: [ 21, Float::INFINITY ] },
      fat: { low: [ 0, 5 ], medium: [ 6, 15 ], high: [ 16, Float::INFINITY ] },
      carbohydrates: { low: [ 0, 30 ], medium: [ 31, 60 ], high: [ 61, Float::INFINITY ] },
      vitamins: { low: [ 0, 5 ], medium: [ 6, 10 ], high: [ 11, Float::INFINITY ] },
      mineral: { low: [ 0, 5 ], medium: [ 6, 10 ], high: [ 11, Float::INFINITY ] }
    }
  end

  def calculate_nutrition(foods)
    nutrition_totals = {
      protein: 0.0,
      fat: 0.0,
      carbohydrates: 0.0,
      vitamins: 0.0,
      mineral: 0.0
    }

    # 各食品の栄養素を合計する
    foods.each do |food|
      food.nutritions.each do |nutrition|
        nutrition_totals[:protein] += nutrition.protein.to_f
        nutrition_totals[:fat] += nutrition.fat.to_f
        nutrition_totals[:carbohydrates] += nutrition.carbohydrates.to_f
        nutrition_totals[:vitamins] += nutrition.vitamins.to_f
        nutrition_totals[:mineral] += nutrition.mineral.to_f
      end
    end

    nutrition_totals
  end
# 栄養素の値を計算する（仮のロジック）
def calculate_nutrient_value(nutrient, food_name)
  case nutrient
  when "protein"
    food_name.include?("肉") ? 10.0 : 5.0
  when "fat"
    food_name.include?("油") ? 15.0 : 3.0
  when "carbohydrates"
    food_name.include?("米") ? 20.0 : 10.0
  when "vitamins"
    food_name.include?("野菜") ? 8.0 : 2.0
  when "mineral"
    food_name.include?("魚") ? 5.0 : 1.0
  else
    0.0
  end
end
end
