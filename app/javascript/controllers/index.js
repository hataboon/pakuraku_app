// app/javascript/controllers/index.js
import { Application } from "@hotwired/stimulus"
import NutritionChartController from "./nutrition_chart_controller"
import DropdownController from "./dropdown_controller" // 追加

// アプリケーションのインスタンスを作成
const application = Application.start()

// コントローラーを登録
application.register("nutrition-chart", NutritionChartController)
application.register("dropdown", DropdownController) // 追加

export { application }