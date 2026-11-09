class Api::V1::SessionsController < ApplicationController
  rate_limit to: 10, within: 3.minutes, only: :create,
             with: -> {
               render json: {
                 error: "Too many login attempts. Please try again later."
               }, status: :too_many_requests
             }

  def create
    user = User.find_by(email: params.dig(:user, :email).to_s.strip.downcase)

    if user&.authenticate(params.dig(:user, :password).to_s) && user.status == "active"
      access_token = TokenService.encode(user)
      _refresh_record, refresh_token = RefreshToken.create_for(user)

      render json: {
        message: "Login successful",
        user: {
          id: user.id,
          name: user.name,
          email: user.email
        },
        access_token: access_token,
        refresh_token: refresh_token,
        token_type: "Bearer",
        expires_in: TokenService::ACCESS_TOKEN_TTL.to_i
      }, status: :ok
    else
      render json: {
        error: "Invalid email or password"
      }, status: :unauthorized
    end
  end

  def destroy
    raw_token = params[:refresh_token].to_s

    if raw_token.blank?
      return render json: {
        error: "Refresh token is required"
      }, status: :unauthorized
    end

    digest = Digest::SHA256.hexdigest(raw_token)

    refresh_token = RefreshToken.find_by(token_digest: digest)

    unless refresh_token&.active?
      return render json: {
        error: "Invalid or expired refresh token"
      }, status: :unauthorized
    end

    refresh_token.revoke!

    render json: {
      message: "Logout successful"
    }, status: :ok
  end
end