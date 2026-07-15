class User < ActiveRecord::Base
  class GoogleEmailNotVerifiedError < StandardError; end
  class GoogleAccountAlreadyLinkedError < StandardError; end


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

  # Raises Google::Auth::IDTokens::VerificationError for a forged/expired/wrong-audience token.
  def self.verify_google_id_token(id_token)
    client_ids = [ENV.fetch('GOOGLE_CLIENT_ID'), ENV['GOOGLE_IOS_CLIENT_ID']].compact
    Google::Auth::IDTokens.verify_oidc(id_token, aud: client_ids)
  end

  # Verifies a Google ID token and finds, links, or creates the matching User.
  # Raises Google::Auth::IDTokens::VerificationError for a forged/expired/wrong-audience token.
  def self.from_google_id_token(id_token)
    payload = verify_google_id_token(id_token)
    raise GoogleEmailNotVerifiedError unless payload['email_verified']

    user = find_by(google_uid: payload['sub'])
    return user if user

    user = find_by(email: payload['email'])
    if user
      user.update!(google_uid: payload['sub'])
    else
      user = create!(
        email: payload['email'],
        name: payload['name'],
        google_uid: payload['sub'],
        password: SecureRandom.hex(32),
        password_set: false
      )
    end

    user
  end

  def self.link_google_id_token(id_token, user)
    payload = verify_google_id_token(id_token)


    raise GoogleEmailNotVerifiedError unless payload['email_verified']

    raise GoogleAccountAlreadyLinkedError if user.google_uid
    raise GoogleAccountAlreadyLinkedError if where(google_uid: payload['sub']).where.not(id: user.id).exists?

    user.update!(google_uid: payload['sub'])
    user
  end

  def to_api_hash

    {
      id: id,
      name: name,
      email: email,
      riddenTramIds: ridden_tram_ids,
      googleLinked: google_uid.present?,
      stats: stats
    }
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
