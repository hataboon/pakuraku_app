class CreateFoods < ActiveRecord::Migration[7.2]
  def change
    create_table :foods do |t|
      t.references :recipe, null: false, foreign_key: true
      t.string :name, null: false
      t.float :quantity, null: false
      t.string :unit, null: false

      t.timestamps
    end
  end
end
