class StaticPagesController < ApplicationController
  def top
    @calendar_plans = CalendarPlan.all
  end
end
