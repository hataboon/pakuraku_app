#!/usr/bin/env bash
# Renderでのビルド時に実行されるスクリプト

# エラーが発生したら即座に停止
set -o errexit

# 1. 必要なパッケージのインストール
echo "Installing dependencies..."
bundle install
yarn install

# 2. アセットのプリコンパイル
echo "Precompiling assets..."
RAILS_ENV=production bundle exec rake assets:precompile

# 3. Tailwind CSSのビルド
echo "Building Tailwind CSS..."
yarn run tailwindcss -i ./app/assets/stylesheets/application.tailwind.css -o ./app/assets/builds/application.css --minify

# 4. データベースのマイグレーション
echo "Running database migrations..."
RAILS_ENV=production bundle exec rake db:migrate

echo "Build completed successfully!"