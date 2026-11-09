class User < ApplicationRecord
  has_secure_password

  has_many :baskets, dependent: :restrict_with_error
  has_many :refresh_tokens, dependent: :destroy

  before_validation :normalize_email
  before_update :record_password_change,
              if: :will_save_change_to_password_digest?

  validates :name, presence: true

  validates :email,
            presence: true,
            uniqueness: { case_sensitive: false },
            format: { with: URI::MailTo::EMAIL_REGEXP }

  validates :status,
            inclusion: { in: %w[active inactive] }

  validates :password,
            length: { minimum: 8 },
            if: -> { password.present? }

  # Generate a secure password reset token
  def generate_password_reset_token!
    token = SecureRandom.urlsafe_base64(32)

    update!(
      password_reset_token_digest: Digest::SHA256.hexdigest(token),
      password_reset_expires_at: 30.minutes.from_now
    )

    token
  end

  # Check whether a password reset token is valid
  def valid_password_reset_token?(token)
    return false if password_reset_token_digest.blank?
    return false if password_reset_expires_at.blank?
    return false if password_reset_expires_at <= Time.current

    digest = Digest::SHA256.hexdigest(token)

    ActiveSupport::SecurityUtils.secure_compare(
      password_reset_token_digest,
      digest
    )
  end

  private

  def normalize_email
    self.email = email.to_s.strip.downcase
  end

  def record_password_change
  self.password_changed_at = Time.current
end
end