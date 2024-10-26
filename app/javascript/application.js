// Entry point for the build script in your package.json
import "@hotwired/turbo-rails";
import "./controllers";
import { Turbo } from "@hotwired/turbo-rails";
import "./calendar";
Turbo.session.drive = false;  // Turboを無効化
