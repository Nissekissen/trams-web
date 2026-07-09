class Tram < ActiveRecord::Base
  belongs_to :model
  has_many :rides, dependent: :destroy

  validates :number, presence: true

  def self.ordered
    order(:number)
  end

  def lines_seen_on
    rides.distinct.pluck(:line).sort
  end

  def to_api_hash
    {
      id: id,
      number: number,
      model: model.to_api_hash,
      linesSeenOn: lines_seen_on.map(&:to_s),
    }
  end
end
