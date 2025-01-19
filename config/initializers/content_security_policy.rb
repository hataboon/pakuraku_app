# config/initializers/content_security_policy.rb

Rails.application.configure do
  config.content_security_policy do |policy|
    # 基本的なセキュリティポリシー
    policy.default_src :self, :https
    policy.font_src    :self, :https, :data
    policy.img_src     :self, :https, :data
    policy.object_src  :none
    policy.script_src  :self, :https
    policy.style_src   :self, :https

    # Xとの連携のために追加
    policy.connect_src :self, :https, "https://twitter.com"
    policy.frame_src   :self, :https, "https://twitter.com"
  end

  # 以下の設定はそのまま残します
  config.content_security_policy_nonce_generator = ->(request) { request.session.id.to_s }
  config.content_security_policy_nonce_directives = %w[script-src style-src]
end
