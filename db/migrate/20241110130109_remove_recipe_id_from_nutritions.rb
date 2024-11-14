class RemoveRecipeIdFromNutritions < ActiveRecord::Migration[7.2]
  def change
    remove_reference :nutritions, :recipe, foreign_key: true # `recipe_id`を削除
  end
end
