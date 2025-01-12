// app/javascript/application.js
import { Turbo } from "@hotwired/turbo-rails"
import { Application } from "@hotwired/stimulus"
import "./controllers"
import "./packs/calendar"

// Turboの初期化
window.Turbo = Turbo

// Stimulusの初期化
const application = Application.start()

// CSRFトークンの設定
document.addEventListener("turbo:load", () => {
  const token = document.querySelector('meta[name="csrf-token"]')?.content
  if (token) {
    window.csrfToken = token
  }
})

// DELETEリクエストの処理
document.addEventListener("turbo:before-fetch-request", (event) => {
  if (event.detail.fetchOptions.method.toLowerCase() === 'delete') {
    // CSRFトークンを追加
    event.detail.fetchOptions.headers = {
      ...event.detail.fetchOptions.headers,
      'X-CSRF-Token': window.csrfToken
    }
  }
})

// 従来のイベントリスナーは削除
// document.addEventListener("DOMContentLoaded", () => { ... });
// function handleClick(e) { ... }