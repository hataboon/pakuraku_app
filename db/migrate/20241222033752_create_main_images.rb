class CreateMainImages < ActiveRecord::Migration[8.0]
  def change
    create_table :main_images do |t|
      t.timestamps
    end
  end
end
