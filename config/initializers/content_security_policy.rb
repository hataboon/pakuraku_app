# config/initializers/content_security_policy.rb
Rails.application.config.content_security_policy do |policy|
  # 基本設定
  policy.default_src :self, :https
  policy.font_src    :self, :https, :data
  policy.img_src     :self, :https, :data
  policy.script_src  :self, :https, "'unsafe-inline'"
  policy.style_src   :self, :https, "'unsafe-inline'"

  # Twitter連携用
  policy.connect_src :self, :https, "https://twitter.com"
  policy.frame_src   :self, :https, "https://twitter.com"

  # Render用（本番環境のみ）
  if Rails.env.production?
    host = "pakuraku-app.onrender.com"
    policy.connect_src :self, :https, "https://#{host}"
    policy.img_src     :self, :https, :data, "https://#{host}"
  end
end

# 開発環境でのみレポートモードを有効化
Rails.application.config.content_security_policy_report_only = Rails.env.development?
