class Ride < ActiveRecord::Base
  belongs_to :tram
  belongs_to :user

  LINES = (1..12).to_a
  validates :line, inclusion: { in: LINES }

  LINE_COLORS = {
    1  => { bg: '#fefefe', text: '#221e1f' },
    2  => { bg: '#fedc00', text: '#00384d' },
    3  => { bg: '#0079c1', text: '#fefefe' },
    4  => { bg: '#00a05f', text: '#fefefe' },
    5  => { bg: '#ee3c41', text: '#fefefe' },
    6  => { bg: '#f79627', text: '#00384d' },
    7  => { bg: '#9c5606', text: '#fefefe' },
    8  => { bg: '#a54399', text: '#fefefe' },
    9  => { bg: '#b8e2f8', text: '#00384d' },
    10 => { bg: '#c8de8d', text: '#00384d' },
    11 => { bg: '#221e1f', text: '#fefefe' },
    12 => { bg: '#55c1b5', text: '#00384d' }
  }.freeze

  def self.ordered
    order(:ridden_on)
  end

  def self.color_for(line)
    LINE_COLORS.fetch(line)
  end
end
