class Recipe < ApplicationRecord
  attr_accessor :nutrition_data

  has_many :foods, dependent: :destroy
  has_many :calendar_plans, dependent: :destroy

  CATEGORIES = {
    japanese: "和食",
    chinese: "中華",
    western: "洋食"
  }.freeze
end
