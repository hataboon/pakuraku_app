class AddAgeAndGenderToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :age, :integer
    add_column :users, :gender, :string
  end
end
