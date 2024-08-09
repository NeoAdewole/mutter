class Identity < ApplicationRecord
  belongs_to :user
  validates :uuid, :provider, presence: true
  validates :uuid, uniqueness: { scope: :provider }
end
