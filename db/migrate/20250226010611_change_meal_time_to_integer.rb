class ChangeMealTimeToInteger < ActiveRecord::Migration[8.0]
  def up
    change_column :calendar_plans, :meal_time, 'integer USING CAST(meal_time AS integer)'
  end

  def down
    change_column :calendar_plans, :meal_time, :string
  end
end
