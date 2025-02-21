class FixNilMealTimes < ActiveRecord::Migration[8.0]
  def up
    # calendar_plansテーブルのmeal_timeカラムを更新する処理
    execute "UPDATE calendar_plans SET meal_time = 0 WHERE meal_time IS NULL"
  end
end
