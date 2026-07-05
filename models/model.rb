class Model < ActiveRecord::Base
  has_many :trams, dependent: :destroy

  validates :name, presence: true

  def self.ordered
    order(:name)
  end

  def to_api_hash
    {
      id: id,
      name: name,
    }
  end
end
