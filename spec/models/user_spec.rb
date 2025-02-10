# spec/models/user_spec.rb
require 'rails_helper'

RSpec.describe User, type: :model do
  describe "バリデーションチェック" do
    context "正常な場合" do
      it "有効なユーザーが作成できること" do
        user = create(:user)
        expect(user).to be_valid
        expect(user.persisted?).to be true
      end

      it "名前が50文字以内であれば有効であること" do
        user = build(:user, name: "a" * 50)
        expect(user).to be_valid
      end

      it "ニックネームが30文字以内であれば有効であること" do
        user = build(:user, nickname: "a" * 30)
        expect(user).to be_valid
      end
      
      it "passwordが6文字以上であれば有効であること" do
        user = build(:user, password: "a" * 6, password_confirmation: "a" * 6)
        expect(user).to be_valid
      end
    end

    context "異常な場合" do
      it "名前がない場合は無効であること" do
        user = build(:user, name: nil)
        expect(user).to be_invalid
      end

      it "名前が51文字以上の場合は無効であること" do
        user = build(:user, name: "a" * 51)
        expect(user).to be_invalid
      end

      it "メールアドレスがない場合は無効であること" do
        user = build(:user, email: nil)
        expect(user).to be_invalid
      end

      it "重複したメールアドレスの場合は無効であること" do
        create(:user, email: "test@example.com")
        user = build(:user, email: "test@example.com")
        expect(user).to be_invalid
      end

      it "ニックネームが31文字以上の場合は無効であること" do
        user = build(:user, nickname: "a" * 31)
        expect(user).to be_invalid
      end
    end
  end
end
