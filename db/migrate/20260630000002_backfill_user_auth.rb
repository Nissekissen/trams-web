class BackfillUserAuth < ActiveRecord::Migration[7.2]
  def up
    require 'bcrypt'
    User.where(email: nil).each do |u|
      u.update_columns(
        email: "#{u.name.downcase.gsub(/\s+/, '.')}@placeholder.local",
        password_digest: BCrypt::Password.create(SecureRandom.hex(32))
      )
    end
  end

  def down
    User.update_all(email: nil, password_digest: nil)
  end
end
