class ChangeCaloriesToMineralInNutritions < ActiveRecord::Migration[7.2]
  def change
    change_table :nutritions do |t|
      t.remove :calories
      t.float :minetal
    end
  end
end
