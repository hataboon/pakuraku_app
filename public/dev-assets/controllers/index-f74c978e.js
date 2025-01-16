// app/javascript/controllers/index.js
import { application } from "./application"
import HelloController from "./hello_controller"
import NutritionChartController from "./nutrition_chart_controller"

application.register("hello", HelloController)
application.register("nutrition-chart", NutritionChartController)