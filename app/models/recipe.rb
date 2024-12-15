class Recipe < ApplicationRecord
  attr_accessor :nutrition_data

  has_many :foods, dependent: :destroy
  has_many :calendar_plans, dependent: :destroy
end
