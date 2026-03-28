class User < ApplicationRecord
  include Devise::JWT::RevocationStrategies::JTIMatcher

  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :jwt_authenticatable, jwt_revocation_strategy: self

  has_many :matches_as_player1, class_name: "Match", foreign_key: :player1_id, dependent: :destroy
  has_many :matches_as_player2, class_name: "Match", foreign_key: :player2_id, dependent: :destroy

  validates :name, presence: true

  def matches
    Match.where("player1_id = ? OR player2_id = ?", id, id)
  end
end
