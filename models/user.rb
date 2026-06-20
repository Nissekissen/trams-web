class User < ActiveRecord::Base
  has_many :rides, dependent: :destroy

  validates :name, presence: true

  def self.ordered
    order(:name)
  end
end