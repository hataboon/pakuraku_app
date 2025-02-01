// app/javascript/application.js
import "@hotwired/turbo-rails"
import { Application } from "@hotwired/stimulus"
import { Chart } from 'chart.js'
import "./controllers"

// Stimulusアプリケーションの初期化
window.Stimulus = Application.start()

// Chart.jsのデフォルト設定
Chart.defaults.font.size = 14
Chart.defaults.responsive = false
Chart.defaults.maintainAspectRatio = false
Chart.defaults.scale.grid.color = 'rgba(0, 0, 0, 0.1)'
Chart.defaults.scale.ticks.color = '#666'

// レーダーチャート特有の設定
Chart.defaults.radar = {
  scale: {
    r: {
      angleLines: {
        color: 'rgba(0, 0, 0, 0.1)'
      },
      grid: {
        color: 'rgba(0, 0, 0, 0.1)'
      },
      pointLabels: {
        font: {
          size: 14
        }
      },
      ticks: {
        beginAtZero: true,
        stepSize: 20,
        max: 100
      }
    }
  }
}

// CSRF対策
document.addEventListener("turbo:load", () => {
  const token = document.querySelector('meta[name="csrf-token"]')?.content
  if (token) {
    window.csrfToken = token
  }
})

document.addEventListener("turbo:before-fetch-request", (event) => {
  if (event.detail.fetchOptions.method.toLowerCase() === 'delete') {
    event.detail.fetchOptions.headers = {
      ...event.detail.fetchOptions.headers,
      'X-CSRF-Token': window.csrfToken
    }
  }
})