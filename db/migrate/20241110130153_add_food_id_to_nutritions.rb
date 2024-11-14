class AddFoodIdToNutritions < ActiveRecord::Migration[7.2]
  def change
    remove_reference :nutritions, :recipe, foreign_key: true # `recipe_id`を削除
    add_reference :nutritions, :food, null: false, foreign_key: true # `food_id`を追加
  end
end
