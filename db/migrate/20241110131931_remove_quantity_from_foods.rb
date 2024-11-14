class RemoveQuantityFromFoods < ActiveRecord::Migration[7.2]
  def change
    remove_column :foods, :quantity, :float
  end
end
