class ChangeNutritionColumnsTypeToFloat < ActiveRecord::Migration[7.2]
  def change
    change_column :nutritions, :protein, :float, using: 'protein::float'
    change_column :nutritions, :fat, :float, using: 'fat::float'
    change_column :nutritions, :carbohydrates, :float, using: 'carbohydrates::float'
    change_column :nutritions, :vitamins, :float, using: 'vitamins::float'
    change_column :nutritions, :mineral, :float, using: 'mineral::float'
  end
end
