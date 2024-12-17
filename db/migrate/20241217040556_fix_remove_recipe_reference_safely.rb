class FixRemoveRecipeReferenceSafely < ActiveRecord::Migration[6.0]
  def change
    # 外部キーが存在する場合のみ削除
    if foreign_key_exists?(:nutritions, :recipe)
      remove_reference :nutritions, :recipe, foreign_key: true
    else
      puts "Foreign key for 'recipes' already removed, skipping."
    end

    # 新しいリファレンスを追加
    add_reference :nutritions, :food, foreign_key: true
  end
end
