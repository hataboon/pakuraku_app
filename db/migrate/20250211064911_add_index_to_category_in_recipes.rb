class AddIndexToCategoryInRecipes < ActiveRecord::Migration[8.0]
  def change
    add_index :recipes, :category
  end
end
