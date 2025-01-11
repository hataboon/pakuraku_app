# frozen_string_literal: true

class Users::SessionsController < Devise::SessionsController
  before_action :configure_sign_in_params, only: [ :create ]

  # GET /resource/sign_in
  # def new
  #   super
  # end

  # POST /resource/sign_in
  def create
    user = User.find_by(email: params[:email])

    # パスワードの認証を確認
    if user&.valid_password?(params[:password])
      # ログイン成功
      sign_in(user)
      redirect_to root_path, notice: "ログインに成功しました。"
    else
      # ログイン失敗
      flash.now[:alert] = "メールアドレスまたはパスワードが間違っています。"
      render :new, status: :unprocessable_entity
    end
  end

  # DELETE /resource/sign_out
  def destroy
    super
  end

  protected

  # If you have extra params to permit, append them to the sanitizer.
  def configure_sign_in_params
    devise_parameter_sanitizer.permit(:sign_in, keys: [ :email, :password, :remember_me ])
  end
end
