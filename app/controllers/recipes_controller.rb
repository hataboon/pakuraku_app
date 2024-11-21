require "openai"

class RecipesController < ApplicationController
  include NutritionsHelper

  def new
    @recipe = Recipe.new
  end

  def create
    desired_nutrients = params[:desired_nutrients] || []
    nutrients_list = desired_nutrients.join(", ") # 例: "タンパク質, ビタミンC"
    @meal_plans = generate_meal_plan_with_openai(nutrients_list)

    if @meal_plans.present?
      created_recipe_ids = []
      @meal_plans.each do |meal_plan|
        Rails.logger.info("保存対象の献立データ: #{meal_plan.inspect}")

        recipe = Recipe.create(name: meal_plan[:name].presence || "Auto-generated Recipe")
        if recipe.persisted?
          Rails.logger.info("保存されたRecipe: #{recipe.name}")
          save_ingredients_and_nutrition(meal_plan, recipe)
          created_recipe_ids << recipe.id
        else
          Rails.logger.warn("Recipeの保存に失敗: #{recipe.errors.full_messages.join(', ')}")
        end
      end

      session[:created_recipe_ids] = created_recipe_ids
      redirect_to recipe_path(created_recipe_ids.last), notice: "レシピが正常に作成されました。"
    else
      flash.now[:alert] = "レシピの保存に失敗しました。"
      render :new
    end
  end

  def show
    # セッションからレシピIDを取得
    recipe_ids = session[:created_recipe_ids] || []
    @recipes = Recipe.where(id: recipe_ids)
  
    # 献立データの作成
    @meal_plans = @recipes.map do |recipe|
      {
        id: recipe.id,
        name: recipe.name,
        ingredients: recipe.foods.pluck(:name),
        nutrients: recipe.foods.map do |food|
          {
            protein: food.nutritions.sum(:protein),
            fat: food.nutritions.sum(:fat),
            carbohydrates: food.nutritions.sum(:carbohydrates),
            vitamins: food.nutritions.pluck(:vitamins).join(", "),
            mineral: food.nutritions.pluck(:mineral).join(", ")
          }
        end
      }
    end
  
    # 栄養素の判定を追加
    @categorized_nutrients = @meal_plans.map do |meal_plan|
      total_nutrients = {
        minerals: meal_plan[:nutrients].sum { |n| n[:mineral].to_f },
        calories:  meal_plan[:nutrients].sum { |n| n[:protein].to_f * 4 + n[:fat].to_f * 9 + n[:carbohydrates].to_f * 4 },
        protein:   meal_plan[:nutrients].sum { |n| n[:protein].to_f },
        fat:       meal_plan[:nutrients].sum { |n| n[:fat].to_f },
        carbohydrates: meal_plan[:nutrients].sum { |n| n[:carbohydrates].to_f }
      }
      categorize_nutrients(total_nutrients) # ヘルパーで判定
    end
  
    # デバッグログを出力
    Rails.logger.debug("生成された@meal_plans: #{@meal_plans.inspect}")
    Rails.logger.debug("判定された@categorized_nutrients: #{@categorized_nutrients.inspect}")
  end
  
  

  private

  def save_ingredients_and_nutrition(meal_plan, recipe)
    meal_plan[:ingredients].each do |ingredient_name|
      Rails.logger.debug("保存しようとしている食材データ: #{ingredient_name}")
      food = recipe.foods.create(name: ingredient_name, unit: "個")

      if food.persisted?
        Rails.logger.info("保存されたFood: #{food.name}")
        save_nutrition(meal_plan[:nutrients], food)
      else
        Rails.logger.warn("Foodの保存に失敗しました: #{ingredient_name}")
      end
    end
  end

  def save_nutrition(nutrients, food)
    nutrients.each do |nutrient|
      # 追加: データ型確認と例外処理
      unless nutrient.is_a?(Hash)
        Rails.logger.error("栄養データが不正です: #{nutrient.inspect}")
        next
      end

      Rails.logger.debug("保存しようとしている栄養素データ: #{nutrient.inspect}")
      food.nutritions.create!(
        protein: nutrient[:protein].to_f,
        fat: nutrient[:fat].to_f,
        carbohydrates: nutrient[:carbohydrates].to_f,
        vitamins: nutrient[:vitamins],
        mineral: nutrient[:mineral]
      )
    end
  end

  def build_meal_plans(recipes)
    total_nutrition = {
      protein: 0.0,
      fat: 0.0,
      carbohydrates: 0.0,
      vitamins: [],
      mineral: []
    }

    meal_plans = recipes.map do |recipe|
      {
        id: recipe.id,
        name: recipe.name,
        ingredients: recipe.foods.pluck(:name),
        nutrients: recipe.foods.map do |food|
          {
            protein: food.nutritions.sum(:protein),
            fat: food.nutritions.sum(:fat),
            carbohydrates: food.nutritions.sum(:carbohydrates),
            vitamins: food.nutritions.pluck(:vitamins).join(", "),
            mineral: food.nutritions.pluck(:mineral).join(", ")
          }
        end
      }
    end

    meal_plans.each do |meal_plan|
      meal_plan[:nutrients].each do |nutrient|
        total_nutrition[:protein] += nutrient[:protein].to_f
        total_nutrition[:fat] += nutrient[:fat].to_f
        total_nutrition[:carbohydrates] += nutrient[:carbohydrates].to_f
      end
    end

    [meal_plans, total_nutrition]
  end

  def generate_meal_plan_with_openai(nutrients_list)
    client = OpenAI::Client.new(access_token: ENV["OPENAI_API_KEY"])

    prompt = <<~PROMPT
      以下の栄養素に基づいた献立を作成してください:
      - #{nutrients_list}

      栄養バランスを考慮し、3つの献立を提案してください。各献立には必ず以下の情報を含めてください：
      1. 「献立タイトル: <タイトル>」
      2. 「食材: <食材リスト>」
      3. 栄養素の内訳として、以下を記載：
        - 炭水化物: <数値>
        - 脂質: <数値>
        - タンパク質: <数値>
        - ビタミン: <ビタミンの種類>
        - ミネラル: <ミネラルの種類>
    PROMPT

    response = client.chat(
      parameters: {
        model: "gpt-3.5-turbo",
        messages: [{ role: "user", content: prompt }]
      }
    )

    if response["choices"].present?
      parse_openai_response(response["choices"].first["message"]["content"])
    else
      Rails.logger.warn("OpenAIのレスポンスが空です。")
      []
    end
  end

  def parse_openai_response(response_text)
    meal_plans = []

    response_text.split("\n\n").each do |section|
      lines = section.lines.map(&:strip)
      recipe_name = lines.find { |line| line.include?("献立タイトル:") }&.split(":", 2)&.last&.strip || "タイトルなし"
      ingredients_list = lines.find { |line| line.include?("食材:") }&.split(":", 2)&.last&.strip&.split("、") || []
      protein_value = lines.find { |line| line.include?("タンパク質:") }&.match(/\d+/)&.to_s&.to_f || 0
      fat_value = lines.find { |line| line.include?("脂質:") }&.match(/\d+/)&.to_s&.to_f || 0
      carbohydrates_value = lines.find { |line| line.include?("炭水化物:") }&.match(/\d+/)&.to_s&.to_f || 0
      vitamins_list = lines.find { |line| line.include?("ビタミン:") }&.split(":", 2)&.last&.strip || "なし"
      mineral_list = lines.find { |line| line.include?("ミネラル:") }&.split(":", 2)&.last&.strip || "なし"

      meal_plans << {
        name: recipe_name,
        ingredients: ingredients_list,
        nutrients: [
          {
            protein: protein_value,
            fat: fat_value,
            carbohydrates: carbohydrates_value,
            vitamins: vitamins_list,
            mineral: mineral_list
          }
        ]
      }
    end

    meal_plans
  end
end
