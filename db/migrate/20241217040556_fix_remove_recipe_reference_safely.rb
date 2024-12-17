class FixRemoveRecipeReferenceSafely < ActiveRecord::Migration[6.0]
  def change
    reversible do |dir|
      dir.up do
        # 外部キーが存在する場合のみ削除
        if foreign_key_exists?(:nutritions, :recipe)
          remove_reference :nutritions, :recipe, foreign_key: true
        end
      end

      dir.down do
        # ロールバック時に追加
        add_reference :nutritions, :recipe, foreign_key: true
      end
    end
  end
end
