// app/javascript/controllers/dropdown_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu"]

  connect() {
    // デバッグ用（必要に応じて）
    console.log("Dropdown controller connected")
  }

  toggle() {
    this.menuTarget.classList.toggle("hidden")
  }

  closeIfClickedOutside(event) {
    if (!this.element.contains(event.target)) {
      this.menuTarget.classList.add("hidden")
    }
  }
}