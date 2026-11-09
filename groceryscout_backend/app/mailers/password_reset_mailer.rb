class PasswordResetMailer < ApplicationMailer
  def reset(user, token)
    @user = user
    @token = token

    reset_url = "#{ENV.fetch("FRONTEND_URL", "http://localhost:3001")}/reset-password?token=#{CGI.escape(@token)}"

    mail(
      to: @user.email,
      subject: "Reset your GroceryScout password"
    ) do |format|
      format.text do
        render plain: <<~BODY
          Hello #{@user.name},

          We received a request to reset your GroceryScout password.

          Click the link below to choose a new password:

          #{reset_url}

          This link expires in 30 minutes.

          If you did not request this reset, you can ignore this email.
        BODY
      end
    end
  end
end