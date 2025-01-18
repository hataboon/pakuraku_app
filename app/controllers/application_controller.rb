class ApplicationController < ActionController::Base
  allow_browser versions: :modern
  before_action :configure_permitted_parameters, if: :devise_controller?

  protected

  def configure_permitted_parameters
    # 新規登録時のパラメータ
    devise_parameter_sanitizer.permit(:sign_up, keys: [ :name, :nickname, :avatar ])  # avatarとnicknameを追加
    # アカウント更新時のパラメータ
    devise_parameter_sanitizer.permit(:account_update, keys: [ :name, :nickname, :avatar ])  # avatarとnicknameを追加
  end
end
