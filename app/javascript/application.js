// Entry point for the build script in your package.json
import "@hotwired/turbo-rails";
import Rails from "@rails/ujs";
import "./controllers";
import "./packs/calendar";

Rails.start();