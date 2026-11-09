class TokenService
  ACCESS_TOKEN_TTL = 15.minutes

  def self.encode(user)
    payload = {
      sub: user.id,
      exp: ACCESS_TOKEN_TTL.from_now.to_i,
      iat: Time.current.to_f
    }

    JWT.encode(
      payload,
      Rails.application.secret_key_base,
      "HS256"
    )
  end

  def self.decode(token)
    JWT.decode(
      token,
      Rails.application.secret_key_base,
      true,
      algorithm: "HS256"
    ).first
  end
end