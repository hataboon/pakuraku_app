import { Controller } from "@hotwired/stimulus"
import Chart from "chart.js/auto"

export default class extends Controller {
  connect() {
    const ctx = this.element.getContext('2d')
    const data = JSON.parse(this.element.dataset.nutritionChartData)

    this.chart = new Chart(ctx, {
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
            max: 100,  // ここを100に固定
            ticks: { 
              stepSize: 20
            }
          }
        }
      }
    })
  }

  disconnect() {
    if (this.chart) {
      this.chart.destroy()
    }
  }
}