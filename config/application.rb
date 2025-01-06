require_relative "boot"
require "rails/all"

Bundler.require(*Rails.groups)

module Myapp
  class Application < Rails::Application
    # Rails 7.2の初期設定
    config.load_defaults 7.2

    # デフォルトのロケールを日本語に設定
    config.i18n.default_locale = :ja

    # assetsパスにJavaScriptフォルダを追加
    config.assets.paths << Rails.root.join("app/assets/builds")
    config.assets.paths << Rails.root.join("app/assets/javascripts")
    # タイムゾーン設定（例：日本時間）
    config.time_zone = "Tokyo"

    # lib以下のディレクトリを自動読み込み
    config.autoload_paths << Rails.root.join("lib")

    # その他の設定は必要に応じて追加
    config.active_support.to_time_preserves_timezone = :zone
  end
end
