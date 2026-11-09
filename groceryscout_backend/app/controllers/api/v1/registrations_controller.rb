class Api::V1::RegistrationsController < ApplicationController
  def create
    user = User.new(registration_params)

    if user.save
      access_token = TokenService.encode(user)
      _refresh_record, refresh_token = RefreshToken.create_for(user)

      render json: {
        message: "Registration successful",
        user: {
          id: user.id,
          name: user.name,
          email: user.email
        },
        access_token: access_token,
        refresh_token: refresh_token,
        token_type: "Bearer",
        expires_in: TokenService::ACCESS_TOKEN_TTL.to_i
      }, status: :created
    else
      render json: {
        errors: user.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  private

  def registration_params
    params.require(:user).permit(
      :name,
      :email,
      :password
    )
  end
end