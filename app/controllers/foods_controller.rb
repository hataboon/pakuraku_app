class FoodsController < ApplicationController
  def index
    @calendar_plans = CalendarPlan.all  # カレンダープランのデータ
  end
end
