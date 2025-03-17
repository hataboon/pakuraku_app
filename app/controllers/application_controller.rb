class ApplicationController < ActionController::Base
  allow_browser versions: :modern
  before_action :configure_permitted_parameters, if: :devise_controller?

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [ :name, :nickname, :avatar ])  # avatarとnicknameを追加
    devise_parameter_sanitizer.permit(:account_update, keys: [ :name, :nickname, :avatar ])  # avatarとnicknameを追加
  end

  def set_date_range
    @date = params[:date].present? ? Time.zone.parse(params[:date]).to_date : Time.zone.today
    @start_date = @date.beginning_of_month
    @end_date = @date.end_of_month
  end
end
