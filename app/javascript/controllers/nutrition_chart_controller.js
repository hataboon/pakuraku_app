// app/javascript/controllers/nutrition_chart_controller.js
import { Controller } from "@hotwired/stimulus"
import Chart from "chart.js/auto"

export default class extends Controller {
  static targets = ["canvas"]
  
  connect() {
    if (this.hasChartInstance) return
    this.initializeChart()
  }

  initializeChart() {
    if (!this.element) return

    try {
      const data = JSON.parse(this.element.dataset.nutritionChartData)
      const ctx = this.element.getContext('2d')

      // キャンバスのサイズを明示的に設定
      this.element.style.width = '400px'
      this.element.style.height = '400px'
      this.element.width = 400
      this.element.height = 400

      // チャートの設定
      const config = {
        type: 'radar',
        data: {
          labels: ['タンパク質', '炭水化物', '脂質', 'ビタミン', 'ミネラル'],
          datasets: [{
            label: '栄養バランス',
            data: [
              data.protein,
              data.carbohydrates,
              data.fat,
              data.vitamins,
              data.minerals
            ],
            backgroundColor: 'rgba(54, 162, 235, 0.2)',
            borderColor: 'rgb(54, 162, 235)',
            pointBackgroundColor: 'rgb(54, 162, 235)'
          }]
        },
        options: {
          responsive: false,
          maintainAspectRatio: false,
          scales: {
            r: {
              beginAtZero: true,
              max: 100,
              ticks: { 
                stepSize: 20,
                font: {
                  size: 12
                }
              }
            }
          },
          plugins: {
            legend: {
              display: true,
              position: 'top',
              labels: {
                font: {
                  size: 12
                }
              }
            }
          }
        }
      }

      this.chart = new Chart(ctx, config)
      this.hasChartInstance = true

    } catch (error) {
      console.error('グラフの初期化エラー:', error)
    }
  }

  disconnect() {
    if (this.chart) {
      this.chart.destroy()
      this.chart = null
      this.hasChartInstance = false
    }
  }
}