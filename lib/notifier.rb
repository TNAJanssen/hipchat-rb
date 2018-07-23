require "action_mailer"

ActionMailer::Base.delivery_method = :smtp
ActionMailer::Base.smtp_settings = {
    :enable_starttls_auto => true,
}

class Notifier < ActionMailer::Base

  def deploy_notification(toEmail, fromEmail, subject, body, options = {
      host => '',
      port => '',
      user_name => '',
      password => '',
      tls => true,
  })
    mail(:to => toEmail,
         :from => fromEmail,
         :address => options.host,
         :port => options.port,
         :user_name => options.user_name,
         :password => options.password,
         :tls => options.tls,
         :subject => subject) do |format|
      format.html {render :text => body}
    end
  end
end