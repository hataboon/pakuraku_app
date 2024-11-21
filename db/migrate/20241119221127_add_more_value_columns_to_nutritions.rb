class AddMoreValueColumnsToNutritions < ActiveRecord::Migration[7.2]
  def change
    add_column :nutritions, :vitamins_value, :float
    add_column :nutritions, :mineral_value, :float
  end
end
