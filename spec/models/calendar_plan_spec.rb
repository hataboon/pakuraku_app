require 'rails_helper'

RSpec.describe CalendarPlan, type: :model do
  describe "バリデーションチェック" do
    context "正常な場合" do
      it "有効なカレンダープランが作成できること" do
        calendar_plan = create(:calendar_plan)
        expect(calendar_plan).to be_valid
        expect(calendar_plan.persisted?).to be true
      end

      it "日付があれば有効であること" do
        calendar_plan = build(:calendar_plan, date: Date.current)
        expect(calendar_plan).to be_valid
      end

      it "時間帯がmorning, afternoon, eveningの場合は有効であること" do
        calendar_plan = build(:calendar_plan, meal_time: "morning")
        expect(calendar_plan).to be_valid
      end
    end

    context "異常な場合" do
      it "日付がない場合は無効であること" do
        calendar_plan = build(:calendar_plan, date: nil)
        expect(calendar_plan).to be_invalid
      end

      it "食事時間がない場合は無効であること" do
        calendar_plan = build(:calendar_plan, meal_time: nil)
        expect(calendar_plan).to be_invalid
      end

      it "食事時間がmorning, afternoon, evening以外の場合は無効であること" do
        calendar_plan = build(:calendar_plan, meal_time: "night")
        expect(calendar_plan).to be_invalid
      end
    end
  end
end
