class CalendarPlansController < ApplicationController
  def destroy
    @calendar_plan = CalendarPlan.find_by(id: params[:id])
    if @calendar_plan
      @calendar_plan.destroy
      flash[:success] = "献立が削除されました。"
    else
      flash[:error] = "献立が見つかりませんでした。"
    end
    redirect_back fallback_location: root_path
  end
end
