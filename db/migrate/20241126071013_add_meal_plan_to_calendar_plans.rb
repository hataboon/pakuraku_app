class AddMealPlanToCalendarPlans < ActiveRecord::Migration[8.0]
  def change
    add_column :calendar_plans, :meal_plan, :text
  end
end
