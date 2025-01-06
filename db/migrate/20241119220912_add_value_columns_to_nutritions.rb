class AddValueColumnsToNutritions < ActiveRecord::Migration[7.2]
  def change
    add_column :nutritions, :protein_value, :float
    add_column :nutritions, :fat_value, :float
    add_column :nutritions, :carbohydrates_value, :float
  end
end
