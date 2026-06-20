class Model < ActiveRecord::Base
  has_many :trams, dependent: :destroy

  validates :name, presence: true

  def self.ordered
    order(:name)
  end
end
