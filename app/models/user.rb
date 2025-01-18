class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  has_many :calendar_plans, dependent: :destroy
  has_one_attached :avatar
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable
  validates :name, presence: true, length: { maximum: 50 }
  validates :nickname, length: { maximum: 30 }
  def avatar_thumbnail
    if avatar.attached?
      avatar
    else
      "default_avatar.png"
    end
  end
end
