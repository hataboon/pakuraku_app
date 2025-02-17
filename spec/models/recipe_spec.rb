require 'rails_helper'

RSpec.describe Recipe, type: :model do
  describe '基本機能' do
    context "正常な場合" do
      it "有効なレシピが作成できること" do
        recipe = create(:recipe)
        expect(recipe).to be_valid
        expect(recipe.persisted?).to be true
      end
      
      it "レシピを削除すると、紐づくカレンダープランも削除されること" do
        recipe = create(:recipe)
        calendar_plan = create(:calendar_plan, recipe: recipe)
        expect { recipe.destroy }.to change(CalendarPlan, :count).by(-1)
      end
    end
  end
end