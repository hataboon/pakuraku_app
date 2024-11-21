class CreateNutritions < ActiveRecord::Migration[7.0]
  def change
    create_table :nutritions do |t|
      t.references :recipe, null: false, foreign_key: true # recipes テーブルとの関連付け
      t.integer :calories                                  # カロリー
      t.float :protein                                     # タンパク質
      t.float :fat                                         # 脂質
      t.float :carbohydrates                               # 炭水化物
      t.string :vitamins                                   # ビタミンの情報（必要に応じて文字列で保存）

      t.timestamps
    end
  end
end
