// app/javascript/controllers/index.js
import { Application } from "@hotwired/stimulus"
import NutritionChartController from "./nutrition_chart_controller"

// アプリケーションのインスタンスを作成
const application = Application.start()

// コントローラーを登録
application.register("nutrition-chart", NutritionChartController)

export { application }