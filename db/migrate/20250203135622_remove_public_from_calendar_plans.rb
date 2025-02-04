class RemovePublicFromCalendarPlans < ActiveRecord::Migration[8.0]
  def change
    remove_column :calendar_plans, :public, :boolean
  end
end
