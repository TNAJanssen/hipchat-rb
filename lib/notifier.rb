require "action_mailer"

ActionMailer::Base.delivery_method = :smtp
ActionMailer::Base.smtp_settings = {
    :enable_starttls_auto => true,
}

class Notifier < ActionMailer::Base

  def deploy_notification(toEmail, fromEmail, subject, body)
    mail(:to => toEmail,
         :from => fromEmail,
         :subject => subject,
         :body => body,
         :content_type => "text/html"
    )
  end
end