class ApplicationController < ActionController::API
  attr_reader :current_user

  def authenticate_user!
    authorization_header = request.headers["Authorization"]

    unless authorization_header.present?
      return render json: {
        error: "Authentication required"
      }, status: :unauthorized
    end

    match = authorization_header.match(/\ABearer ([^\s]+)\z/)

    unless match
      return render json: {
        error: "Invalid authorization format"
      }, status: :unauthorized
    end

    token = match[1]

    begin
      decoded_token = TokenService.decode(token)

      @current_user = User.find_by(id: decoded_token["sub"])

      unless @current_user && @current_user.status == "active"
        return render json: {
          error: "Invalid or inactive account"
        }, status: :unauthorized
      end

      if @current_user.password_changed_at.present? &&
   decoded_token["iat"].to_f < @current_user.password_changed_at.to_f
  return render json: {
    error: "Your password has changed. Please log in again."
  }, status: :unauthorized
end

    rescue JWT::DecodeError
      render json: {
        error: "Invalid or expired token"
      }, status: :unauthorized
    end
  end
end