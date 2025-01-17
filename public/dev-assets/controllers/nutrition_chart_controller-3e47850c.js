// app/javascript/controllers/nutrition_chart_controller.js
import { Controller } from "@hotwired/stimulus"
import Chart from "chart.js/auto"

export default class extends Controller {
  connect() {
    const ctx = this.element.getContext('2d')
    const rawData = this.element.dataset.nutritionChartData
    
    try {
      const data = JSON.parse(rawData)
      
      // データを100以下に正規化する処理を追加
      const normalizedData = {
        protein: Math.min(data.protein, 100),
        carbohydrates: Math.min(data.carbohydrates, 100),
        fat: Math.min(data.fat, 100),
        vitamins: Math.min(data.vitamins, 100),
        minerals: Math.min(data.minerals, 100)
      }

      this.chart = new Chart(ctx, {
        type: 'radar',
        data: {
          labels: ['タンパク質', '炭水化物', '脂質', 'ビタミン', 'ミネラル'],
          datasets: [{
            label: '栄養バランス',
            data: [
              normalizedData.protein,
              normalizedData.carbohydrates,
              normalizedData.fat,
              normalizedData.vitamins,
              normalizedData.minerals
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
              max: 100,  // 最大値を100に固定
              ticks: { stepSize: 20 }
            }
          }
        }
      })
    } catch (error) {
      console.error('Chart initialization error:', error)
    }
  }

  disconnect() {
    if (this.chart) {
      this.chart.destroy()
    }
  }
}