class Api::V1::TokensController < ApplicationController
  def refresh
    raw_token = params[:refresh_token].to_s

    if raw_token.blank?
      return render json: {
        error: "Refresh token is required"
      }, status: :unauthorized
    end

    digest = Digest::SHA256.hexdigest(raw_token)

    result = nil

    RefreshToken.transaction do
      refresh_token = RefreshToken.lock.find_by(token_digest: digest)

      unless refresh_token&.active?
        result = :invalid
        raise ActiveRecord::Rollback
      end

      user = refresh_token.user

      unless user.status == "active"
        result = :invalid
        raise ActiveRecord::Rollback
      end

      if user.password_changed_at.present? &&
   refresh_token.created_at <= user.password_changed_at
  result = :invalid
  raise ActiveRecord::Rollback
end

      refresh_token.revoke!

      _new_record, new_refresh_token = RefreshToken.create_for(user)
      new_access_token = TokenService.encode(user)

      result = {
        access_token: new_access_token,
        refresh_token: new_refresh_token,
        expires_in: TokenService::ACCESS_TOKEN_TTL.to_i
      }
    end

    if result == :invalid
      return render json: {
        error: "Invalid or expired refresh token"
      }, status: :unauthorized
    end

    render json: result, status: :ok
  end
end