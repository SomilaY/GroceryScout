class Api::V1::PasswordsController < ApplicationController
    rate_limit to: 5, within: 15.minutes, only: :forgot,
             with: -> {
               render json: {
                 error: "Too many password reset requests. Please try again later."
               }, status: :too_many_requests
             }

  rate_limit to: 10, within: 15.minutes, only: :reset,
             with: -> {
               render json: {
                 error: "Too many password reset attempts. Please try again later."
               }, status: :too_many_requests
             }
  def forgot
    user = User.find_by(
      email: params.dig(:user, :email).to_s.strip.downcase
    )

   if user && user.status == "active"
  token = user.generate_password_reset_token!

  PasswordResetMailer.reset(user, token).deliver_later
end

    render json: {
      message: "If an account exists with that email, password reset instructions will be sent."
    }, status: :ok
  end

  def reset
    user = User.find_by(
      password_reset_token_digest: Digest::SHA256.hexdigest(
        params[:token].to_s
      )
    )

    if user.nil? || !user.valid_password_reset_token?(params[:token].to_s)
      return render json: {
        error: "Invalid or expired password reset token"
      }, status: :unprocessable_entity
    end

    if user.update(
      password: params.dig(:user, :password),
      password_reset_token_digest: nil,
      password_reset_expires_at: nil
    )
      render json: {
        message: "Password has been reset successfully"
      }, status: :ok
    else
      render json: {
        errors: user.errors.full_messages
      }, status: :unprocessable_entity
    end
  end
end