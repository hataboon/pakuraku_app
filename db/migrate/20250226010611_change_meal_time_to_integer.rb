class ChangeMealTimeToInteger < ActiveRecord::Migration[8.0]
  def up
    # まず一時的なカラムを作成
    add_column :calendar_plans, :meal_time_integer, :integer

    # 既存のデータを変換して一時カラムに保存
    execute <<-SQL
      UPDATE calendar_plans 
      SET meal_time_integer = CASE 
        WHEN meal_time = 'morning' THEN 0
        WHEN meal_time = 'afternoon' THEN 1
        WHEN meal_time = 'evening' THEN 2
        WHEN meal_time = '0' THEN 0
        WHEN meal_time = '1' THEN 1 
        WHEN meal_time = '2' THEN 2
        ELSE 0
      END
    SQL

    # 元のカラムを削除
    remove_column :calendar_plans, :meal_time

    # 新しいカラムの名前を元の名前に変更
    rename_column :calendar_plans, :meal_time_integer, :meal_time
  end

  def down
    # 元に戻す場合の処理
    add_column :calendar_plans, :meal_time_string, :string

    # 整数から文字列に戻す
    execute <<-SQL
      UPDATE calendar_plans 
      SET meal_time_string = CASE 
        WHEN meal_time = 0 THEN 'morning'
        WHEN meal_time = 1 THEN 'afternoon'
        WHEN meal_time = 2 THEN 'evening'
        ELSE 'morning'
      END
    SQL

    remove_column :calendar_plans, :meal_time
    rename_column :calendar_plans, :meal_time_string, :meal_time
  end
end



