class ChangeNutritionColumnsToStrings < ActiveRecord::Migration[7.2]
  def change
    change_column :nutritions, :protein, :string
    change_column :nutritions, :fat, :string
    change_column :nutritions, :carbohydrates, :string
    change_column :nutritions, :vitamins, :string
    change_column :nutritions, :mineral, :string
  end
end
