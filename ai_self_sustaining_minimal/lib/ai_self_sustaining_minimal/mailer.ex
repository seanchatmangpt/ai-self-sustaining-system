defmodule AiSelfSustainingMinimal.Mailer do
  @moduledoc """
  Email delivery service for the minimal AI self-sustaining system.
  
  Provides system notification and communication capabilities using Swoosh.
  Part of the minimal system design focused on essential functionality.
  
  ## Configuration
  
  Configured via Swoosh with OTP app `:ai_self_sustaining_minimal`.
  
  ## Usage
  
      # Send system notification
      import Swoosh.Email
      
      new()
      |> to({"user@example.com", "User Name"})
      |> from({"system@ai-coord.local", "AI Coordination System"})
      |> subject("System Alert")
      |> html_body("<p>System notification</p>")
      |> AiSelfSustainingMinimal.Mailer.deliver()
  
  ## Development
  
  In development, uses local mailbox preview available at `/dev/mailbox`.
  """
  
  use Swoosh.Mailer, otp_app: :ai_self_sustaining_minimal
end
