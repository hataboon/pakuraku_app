class Recipe < ApplicationRecord
  has_many :foods, dependent: :destroy
end
