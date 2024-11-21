module NutritionsHelper
  # 栄養素の基準値
  NUTRIENT_RANGES = {
    minerals: { low: 0..200, adequate: 201..500, high: 501.. }, # ミネラル（合計値）
    calories: { low: 0..300, adequate: 301..700, high: 701.. }, # カロリー
    protein: { low: 0..10, adequate: 11..30, high: 31.. },      # タンパク質
    fat: { low: 0..10, adequate: 11..30, high: 31.. },          # 脂質
    carbohydrates: { low: 0..50, adequate: 51..150, high: 151.. } # 炭水化物
  }.freeze

  # 栄養素を判定するメソッド
  def categorize_nutrients(nutrients)
    results = {} # 判定結果を入れる箱（ハッシュ）

    # 各栄養素の値をチェック
    nutrients.each do |type, value|
      ranges = NUTRIENT_RANGES[type] # 栄養素ごとの基準を取得
      if ranges # 該当する基準があれば判定
        results[type] = case value
        when ranges[:low]
                          "少ない"
        when ranges[:adequate]
                          "適量"
        when ranges[:high]
                          "多い"
        else
                          "不明"
        end
      else
        results[type] = "不明な栄養素" # 基準がない場合
      end
    end

    results # 判定結果を返す
  end
end
