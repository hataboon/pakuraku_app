class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  has_many :calendar_plans, dependent: :destroy
  has_one_attached :avatar

  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :omniauthable, omniauth_providers: [ :google_oauth2 ]

  validates :name, presence: true, length: { maximum: 50 }
  validates :nickname, length: { maximum: 30 }
  validates :age, numericality: { only_integer: true, greater_than: 0, less_than: 120 }, allow_nil: true
  validates :gender, inclusion: { in: [ "male", "female" ] }, allow_nil: true

  def self.from_omniauth(auth)
    # uidとproviderでユーザーを検索し、いなければ作成します
    where(provider: auth.provider, uid: auth.uid).first_or_create do |user|
      # auth.infoからユーザー情報を取得し設定します
      user.email = auth.info.email
      user.password = Devise.friendly_token[0, 20]  # ランダムなパスワードを生成
      user.name = auth.info.name
      # Google アカウントのプロフィール画像を設定（エラー時は無視）
      begin
        user.avatar.attach(io: URI.open(auth.info.image), filename: "#{auth.uid}.jpg") if auth.info.image
      rescue
        # 画像の取得に失敗した場合は無視して続行
      end
    end
  end

  def avatar_thumbnail
    if avatar.attached?
      avatar
    else
      "default_avatar.png"
    end
  end
end
