class User < ActiveRecord::Base
  has_many :rides, dependent: :destroy

  has_secure_password

  validates :name, presence: { message: "kan inte vara tomt" }
  validates :email, presence: { message: "kan inte vara tomt" },
                    uniqueness: { message: "används redan av ett annat konto", case_sensitive: false },
                    format: { message: "har ett ogiltigt format", with: URI::MailTo::EMAIL_REGEXP }

  before_save { self.email = email.downcase }

  def self.ordered
    order(:name)
  end

  def ridden_tram_ids
    rides.distinct.pluck(:tram_id)
  end

  def self.validate_email(email)
    email =~ URI::MailTo::EMAIL_REGEXP
  end

  def generate_token
    update!(api_token: SecureRandom.hex(32))
    api_token
  end

  def stats
    week_start = Date.today - ((Date.today.wday - 1) % 7)

    {
      rideCount: rides.count,
      riddenLineCount: rides.distinct.count(:line),
      riddenTramCount: rides.distinct.count(:tram_id),
      totalTramCount: Tram.count,
      ridesThisWeek: rides.where('ridden_on >= ?', week_start).count
    }
  end
end
