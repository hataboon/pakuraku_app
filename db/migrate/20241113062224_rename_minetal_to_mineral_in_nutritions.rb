class RenameMinetalToMineralInNutritions < ActiveRecord::Migration[7.2]
  def change
    rename_column :nutritions, :minetal, :mineral
  end
end
