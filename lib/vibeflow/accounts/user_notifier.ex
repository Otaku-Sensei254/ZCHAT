defmodule Vibeflow.Accounts.UserNotifier do
  import Swoosh.Email

  alias Vibeflow.Mailer

  # Delivers the email using the application mailer.
  defp deliver(recipient, subject, text_body_content, html_body_content \\ nil) do
    require Logger

    email =
      new()
      |> to(recipient)
      |> from({"VibeFlow", "vibeflowtech@gmail.com"})
      |> subject(subject)
      |> text_body(text_body_content)

    email = if html_body_content, do: html_body(email, html_body_content), else: email

    Logger.info("Sending email to #{recipient}")

    case Mailer.deliver(email) do
      {:ok, _metadata} ->
        Logger.info("Email sent successfully to #{recipient}")
        {:ok, email}

      {:error, reason} ->
        Logger.error("Failed to send email to #{recipient}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Deliver instructions to confirm account.
  """
  def deliver_confirmation_instructions(user, url) do
    deliver(
      user.email,
      "Welcome to VibeFlow - Confirm your email",
      """
Hi #{user.username || user.email},

Welcome to VibeFlow! Please confirm your email address by clicking the link below:

#{url}

This link will expire in 7 days.

If you didn't create an account with us, please ignore this email.

- The VibeFlow Team
      """,
      """
      <html>
      <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px;">
        <div style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); padding: 30px; border-radius: 10px 10px 0 0; text-align: center;">
          <h1 style="color: white; margin: 0; font-size: 24px;">Welcome to VibeFlow!</h1>
        </div>
        <div style="background: #f9f9f9; padding: 30px; border-radius: 0 0 10px 10px;">
          <p>Hi #{user.username || user.email},</p>
          <p>Welcome to VibeFlow! Please confirm your email address by clicking the button below:</p>
          <div style="text-align: center; margin: 30px 0;">
            <a href="#{url}" style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 15px 30px; text-decoration: none; border-radius: 25px; display: inline-block; font-weight: bold;">Confirm Email</a>
          </div>
          <p style="font-size: 14px; color: #666;">This link will expire in 7 days.</p>
          <p style="font-size: 14px; color: #666;">If you didn't create an account with us, please ignore this email.</p>
          <hr style="border: none; border-top: 1px solid #ddd; margin: 30px 0;">
          <p style="font-size: 12px; color: #999; text-align: center;">- The VibeFlow Team</p>
        </div>
      </body>
      </html>
      """
    )
  end

  @doc """
  Deliver instructions to reset a user password.
  """
  def deliver_reset_password_instructions(user, url) do
    deliver(
      user.email,
      "Reset your VibeFlow password",
      """
Hi #{user.username || user.email},

We received a request to reset your VibeFlow password. Click the link below to reset it:

#{url}

This link will expire in 24 hours.

If you didn't request this, please ignore this email. Your password will remain unchanged.

- The VibeFlow Team
      """,
      """
      <html>
      <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px;">
        <div style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); padding: 30px; border-radius: 10px 10px 0 0; text-align: center;">
          <h1 style="color: white; margin: 0; font-size: 24px;">Reset Your Password</h1>
        </div>
        <div style="background: #f9f9f9; padding: 30px; border-radius: 0 0 10px 10px;">
          <p>Hi #{user.username || user.email},</p>
          <p>We received a request to reset your VibeFlow password. Click the button below to reset it:</p>
          <div style="text-align: center; margin: 30px 0;">
            <a href="#{url}" style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 15px 30px; text-decoration: none; border-radius: 25px; display: inline-block; font-weight: bold;">Reset Password</a>
          </div>
          <p style="font-size: 14px; color: #666;">This link will expire in 24 hours.</p>
          <p style="font-size: 14px; color: #666;">If you didn't request this, please ignore this email. Your password will remain unchanged.</p>
          <hr style="border: none; border-top: 1px solid #ddd; margin: 30px 0;">
          <p style="font-size: 12px; color: #999; text-align: center;">- The VibeFlow Team</p>
        </div>
      </body>
      </html>
      """
    )
  end

  @doc """
  Deliver instructions to update a user email.
  """
  def deliver_update_email_instructions(user, url) do
    deliver(
      user.email,
      "Confirm your new email address",
      """
Hi #{user.username || user.email},

You requested to change your email address on VibeFlow. Click the link below to confirm:

#{url}

This link will expire in 7 days.

If you didn't request this change, please ignore this email.

- The VibeFlow Team
      """,
      """
      <html>
      <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px;">
        <div style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); padding: 30px; border-radius: 10px 10px 0 0; text-align: center;">
          <h1 style="color: white; margin: 0; font-size: 24px;">Confirm New Email</h1>
        </div>
        <div style="background: #f9f9f9; padding: 30px; border-radius: 0 0 10px 10px;">
          <p>Hi #{user.username || user.email},</p>
          <p>You requested to change your email address on VibeFlow. Click the button below to confirm:</p>
          <div style="text-align: center; margin: 30px 0;">
            <a href="#{url}" style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 15px 30px; text-decoration: none; border-radius: 25px; display: inline-block; font-weight: bold;">Confirm New Email</a>
          </div>
          <p style="font-size: 14px; color: #666;">This link will expire in 7 days.</p>
          <p style="font-size: 14px; color: #666;">If you didn't request this change, please ignore this email.</p>
          <hr style="border: none; border-top: 1px solid #ddd; margin: 30px 0;">
          <p style="font-size: 12px; color: #999; text-align: center;">- The VibeFlow Team</p>
        </div>
      </body>
      </html>
      """
    )
  end
end
