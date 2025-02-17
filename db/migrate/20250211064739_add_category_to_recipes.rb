class AddCategoryToRecipes < ActiveRecord::Migration[8.0]
  def change
    add_column :recipes, :category, :string
  end
end
