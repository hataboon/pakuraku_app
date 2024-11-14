# app/models/food.rb
class Food < ApplicationRecord
  belongs_to :recipe  # 食材が特定のレシピに属する関係
  has_many :nutritions, dependent: :destroy # 各食材に栄養情報が関連する
end
