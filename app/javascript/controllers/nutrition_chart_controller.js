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
      
      // 推奨値データを取得（あれば）
      let recommendedData = null
      if (this.element.dataset.nutritionChartRecommended) {
        recommendedData = JSON.parse(this.element.dataset.nutritionChartRecommended)
        console.log("Recommended values:", recommendedData)  // デバッグ用
      }

      // データセットの準備
      const datasets = [{
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
      
      // 推奨値があれば2つ目のデータセットとして追加
      if (recommendedData) {
        datasets.push({
          label: '推奨値',
          data: [
            recommendedData.protein || 0,
            recommendedData.carbohydrates || 0,
            recommendedData.fat || 0,
            recommendedData.vitamins || 0,
            recommendedData.minerals || 0
          ],
          backgroundColor: 'rgba(255, 0, 0, 0.0)',  // 透明
          borderColor: 'rgba(255, 0, 0, 0.7)',      // 赤色
          borderWidth: 2,
          pointRadius: 0,                           // ポイントを非表示
          borderDash: [5, 5]                        // 破線
        })
      }

      // データの構造を整形
      const data = {
        labels: ['タンパク質', '炭水化物', '脂質', 'ビタミン', 'ミネラル'],
        datasets: datasets
      }

      // ここから変更部分: スケールの最大値を動的に計算
      let maxScale = 100; // デフォルト値
      
      // 実際のデータの最大値を計算
      const actualValues = [
        parseFloat(chartData.values.protein) || 0,
        parseFloat(chartData.values.carbohydrates) || 0,
        parseFloat(chartData.values.fat) || 0,
        chartData.percentages.vitamins || 0,
        chartData.percentages.minerals || 0
      ];
      
      const dataMax = Math.max(...actualValues);
      
      // 推奨値も考慮
      let recMax = 0;
      if (recommendedData) {
        const recommendedValues = [
          recommendedData.protein || 0,
          recommendedData.carbohydrates || 0,
          recommendedData.fat || 0,
          recommendedData.vitamins || 0,
          recommendedData.minerals || 0
        ];
        recMax = Math.max(...recommendedValues);
      }
      
      // データと推奨値の最大値を比較して、大きい方を基準に
      maxScale = Math.max(maxScale, dataMax * 1.2, recMax * 1.2);
      
      // 適切なステップサイズを計算
      const stepSize = Math.ceil(maxScale / 5);
      
      // ここまで変更部分

      // グラフの初期化
      new Chart(this.element.getContext('2d'), {
        type: 'radar',
        data: data,
        options: {
          scales: {
            r: {
              beginAtZero: true,
              min: 0,
              max: maxScale, // 固定値100から動的計算値に変更
              ticks: {
                stepSize: stepSize // 固定値20から動的計算値に変更
              }
            }
          },
          plugins: {
            legend: {
              display: true
            },
            tooltip: {
              callbacks: {
                label: function(context) {
                  const label = context.dataset.label || '';
                  const value = context.raw;
                  const index = context.dataIndex;
                  
                  // タンパク質、炭水化物、脂質はg単位、ビタミン・ミネラルは%表示
                  if (index < 3) {
                    return `${label}: ${value}g`;
                  } else {
                    return `${label}: ${value}%`;
                  }
                }
              }
            }
          }
        }
      })
    } catch (error) {
      console.error("Error initializing chart:", error)
    }
  }
}