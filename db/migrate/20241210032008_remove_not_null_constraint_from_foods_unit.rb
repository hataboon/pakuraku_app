class RemoveNotNullConstraintFromFoodsUnit < ActiveRecord::Migration[6.1]
  def change
    change_column_null :foods, :unit, true # unitカラムのNOT NULL制約を解除
  end
end
