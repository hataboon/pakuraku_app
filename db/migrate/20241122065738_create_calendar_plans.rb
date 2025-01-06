class CreateCalendarPlans < ActiveRecord::Migration[8.0]
  def change
    create_table :calendar_plans do |t|
      t.references :user, null: false, foreign_key: true
      t.references :recipe, null: false, foreign_key: true
      t.date :date
      t.string :meal_time

      t.timestamps
    end
  end
end
