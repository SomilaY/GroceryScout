require "digest"
require "securerandom"

class RetailerApiCredential < ApplicationRecord
  belongs_to :retailer

  validates :token_digest, presence: true, uniqueness: true

  scope :active, -> { where(revoked_at: nil) }

  def self.digest_token(token)
    Digest::SHA256.hexdigest(token)
  end

  def self.issue_for!(retailer:)
    unless retailer.active?
      raise ArgumentError, "Cannot issue credentials for an inactive retailer"
    end

    raw_token = SecureRandom.urlsafe_base64(32)

    credential = create!(
      retailer: retailer,
      token_digest: digest_token(raw_token)
    )

    [credential, raw_token]
  end

  def active?
    revoked_at.nil? && retailer.active?
  end

  def revoke!
    update!(revoked_at: Time.current) unless revoked_at.present?
  end
end