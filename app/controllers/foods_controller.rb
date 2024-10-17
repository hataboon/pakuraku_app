class FoodsController < ApplicationController
  def index
    @meals = Meal.all # すべての献立データを取得（適宜モデルを調整）
  end
end
