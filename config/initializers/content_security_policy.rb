# config/initializers/content_security_policy.rb

Rails.application.config.content_security_policy do |policy|
  # 基本設定
  policy.default_src :self, :https
  policy.font_src    :self, :https, :data
  policy.img_src     :self, :https, :data, :blob
  policy.script_src  :self, :https, "'unsafe-inline'"
  policy.style_src   :self, :https, "'unsafe-inline'"
  
  # Twitter連携用
  policy.connect_src :self, :https, "https://twitter.com"
  policy.frame_src   :self, :https, "https://twitter.com"
  
  # Render用（本番環境のみ）
  if Rails.env.production?
    # hostからhttps://を削除
    host = "pakuraku-app.onrender.com"
    policy.connect_src :self, :https, "https://#{host}", "wss://#{host}"
    policy.img_src     :self, :https, :data, :blob, "https://#{host}"
  end
end