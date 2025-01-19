# config/initializers/content_security_policy.rb

Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self, :https
    policy.font_src    :self, :https, :data
    policy.img_src     :self, :https, :data
    policy.object_src  :none

    # インラインスクリプトとスタイルを許可
    policy.script_src  :self, :https, :unsafe_inline, :unsafe_eval
    policy.style_src   :self, :https, :unsafe_inline

    # Active Storageのための設定
    policy.img_src     :self, :https, :data, :blob

    # Xとの連携のための設定
    policy.connect_src :self, :https, "https://twitter.com"
    policy.frame_src   :self, :https, "https://twitter.com"

    # Active Storageのための追加設定
    if Rails.env.production?
      # Renderのドメインを許可
      host = "pakuraku-app.onrender.com"
      policy.connect_src :self, :https, "https://#{host}", "wss://#{host}"
      policy.img_src     :self, :https, :data, :blob, "https://#{host}"
    end
  end

  # 既存の設定はそのまま残す
  config.content_security_policy_nonce_generator = ->(request) { request.session.id.to_s }
  config.content_security_policy_nonce_directives = %w[script-src style-src]
end
