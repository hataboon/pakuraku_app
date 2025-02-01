# app/services/nutrition_calculation_service.rb
class NutritionCalculationService
  def initialize(age: 30, gender: "female")
    @age = age
    @gender = gender
  end

  def calculate_daily_requirements
    case @gender
    when "male"
      {
        protein: 65,           # g
        fat: (2700 * 0.25),   # kcal
        carbohydrates: 325,    # g
        vitamins: required_vitamins,
        minerals: required_minerals
      }

    when "female"
      {
        protein: 50,
        fat: (2000 * 0.25),
        carbohydrates: 250,
        vitamins: required_vitamins,
        minerals: required_minerals
      }
    end
  end

  private

  def required_vitamins
    {
      a: 650,     # µg
      d: 8.5,     # µg
      e: 6.0,     # mg
      k: 150,     # µg
      b1: 1.1,    # mg
      b2: 1.2,    # mg
      b6: 1.1,    # mg
      b12: 2.4,   # µg
      c: 100      # mg
    }
  end

  def required_minerals
    {
      calcium: 650,      # mg
      iron: 10.5,        # mg
      zinc: 8,           # mg
      magnesium: 290     # mg
    }
  end
end
