require "test_helper"

class RetailerApiCredentialTest < ActiveSupport::TestCase
  setup do
    @retailer = Retailer.create!(
      name: "Test Retailer",
      slug: "test-retailer",
      website_url: "https://example.com",
      active: true
    )
  end

  test "issues a secure API credential" do
    credential, raw_token =
      RetailerApiCredential.issue_for!(retailer: @retailer)

    assert credential.persisted?
    assert_equal @retailer, credential.retailer
    assert raw_token.present?

    assert_equal(
      RetailerApiCredential.digest_token(raw_token),
      credential.token_digest
    )

    assert_not_equal raw_token, credential.token_digest
    assert credential.active?
  end

  test "generates a different token for each credential" do
    first_credential, first_token =
      RetailerApiCredential.issue_for!(retailer: @retailer)

    second_credential, second_token =
      RetailerApiCredential.issue_for!(retailer: @retailer)

    assert_not_equal first_token, second_token
    assert_not_equal first_credential.token_digest,
                     second_credential.token_digest
  end

  test "cannot issue credentials for an inactive retailer" do
    @retailer.update!(active: false)

    assert_raises(ArgumentError) do
      RetailerApiCredential.issue_for!(retailer: @retailer)
    end
  end

  test "revokes a credential" do
    credential, = RetailerApiCredential.issue_for!(
      retailer: @retailer
    )

    assert credential.active?

    credential.revoke!

    assert_not_nil credential.revoked_at
    assert_not credential.active?
  end

  test "does not revoke an already revoked credential again" do
    credential, = RetailerApiCredential.issue_for!(
      retailer: @retailer
    )

    credential.revoke!
    original_revoked_at = credential.revoked_at

    credential.revoke!

    assert_equal original_revoked_at, credential.reload.revoked_at
  end
end