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
end
