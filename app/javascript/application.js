// app/javascript/application.js
import { Turbo } from "@hotwired/turbo-rails"
import { Application } from "@hotwired/stimulus"
import "./controllers"
import Chart from "chart.js/auto"

// Chart.jsの設定
Chart.defaults.responsive = false
Chart.defaults.maintainAspectRatio = false

// 以下は変更なし
window.Turbo = Turbo
const application = Application.start()

// 既存のイベントリスナーはそのまま維持
document.addEventListener("turbo:load", () => {
  const token = document.querySelector('meta[name="csrf-token"]')?.content
  if (token) {
    window.csrfToken = token
  }
})

// DELETEリクエストの処理
document.addEventListener("turbo:before-fetch-request", (event) => {
  if (event.detail.fetchOptions.method.toLowerCase() === 'delete') {
    event.detail.fetchOptions.headers = {
      ...event.detail.fetchOptions.headers,
      'X-CSRF-Token': window.csrfToken
    }
  }
})