// Entry point for the build script in your package.json
import "@hotwired/turbo-rails";
import Rails from "@rails/ujs";  // Rails UJS のインポート
import "./controllers";
import "./packs/calendar";

Rails.start();  // Rails UJS の起動

// Turboを無効化
import { Turbo } from "@hotwired/turbo-rails";
Turbo.session.drive = false;
