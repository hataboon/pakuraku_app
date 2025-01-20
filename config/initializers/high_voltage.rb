# config/initializers/high_voltage.rb

HighVoltage.configure do |config|
  # URLから /pages/ を省略するための設定
  config.route_drawer = HighVoltage::RouteDrawers::Root

  # レイアウトファイルを指定（application.html.erbを使用する場合）
  config.layout = "application"
end
