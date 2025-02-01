// app/javascript/controllers/nutrition_chart_controller.js
import { Controller } from "@hotwired/stimulus"
import { Chart, RadarController, RadialLinearScale, PointElement, LineElement } from 'chart.js'

// 必要なコンポーネントを登録
Chart.register(RadarController, RadialLinearScale, PointElement, LineElement)

export default class extends Controller {
  connect() {
    console.log("Controller connected")  // デバッグ用

    try {
      const chartData = JSON.parse(this.element.dataset.nutritionChartData)
      console.log("Parsed chart data:", chartData)  // デバッグ用

      // データの構造を整形
      const data = {
        labels: ['タンパク質', '炭水化物', '脂質', 'ビタミン', 'ミネラル'],
        datasets: [{
          label: '栄養バランス',
          data: [
            parseFloat(chartData.values.protein) || 0,
            parseFloat(chartData.values.carbohydrates) || 0,
            parseFloat(chartData.values.fat) || 0,
            chartData.percentages.vitamins || 0,
            chartData.percentages.minerals || 0
          ],
          backgroundColor: 'rgba(54, 162, 235, 0.2)',
          borderColor: 'rgb(54, 162, 235)',
          borderWidth: 1
        }]
      }

      // グラフの初期化
      new Chart(this.element.getContext('2d'), {
        type: 'radar',
        data: data,
        options: {
          scales: {
            r: {
              beginAtZero: true,
              min: 0,
              max: 100,
              ticks: {
                stepSize: 20
              }
            }
          },
          plugins: {
            legend: {
              display: true
            }
          }
        }
      })
    } catch (error) {
      console.error("Error initializing chart:", error)
    }
  }
}