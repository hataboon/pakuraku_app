class AddPublicToCalendarPlans < ActiveRecord::Migration[8.0]
  def change
    add_column :calendar_plans, :public, :boolean, default: false, null: false
    add_index :calendar_plans, :public  # 検索を高速化するためにインデックスを追加
  end
end
