# app/models/nutrition.rb
class Nutrition < ApplicationRecord
  belongs_to :food # 栄養情報は食材に紐づく
end
