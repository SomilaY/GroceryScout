class RefreshToken < ApplicationRecord
  belongs_to :user

  TOKEN_TTL = 30.days

  validates :token_digest, presence: true, uniqueness: true
  validates :expires_at, presence: true

  # Generate a secure refresh token and store only its SHA256 digest.
  def self.create_for(user)
    raw_token = SecureRandom.urlsafe_base64(64)

    refresh_token = user.refresh_tokens.create!(
      token_digest: Digest::SHA256.hexdigest(raw_token),
      expires_at: TOKEN_TTL.from_now
    )

    [refresh_token, raw_token]
  end

  # Check whether this token can still be used.
  def active?
    revoked_at.nil? && expires_at.present? && expires_at > Time.current
  end

  # Revoke this token.
  def revoke!
    update!(revoked_at: Time.current)
  end
end