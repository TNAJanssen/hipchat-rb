require "action_mailer"

ActionMailer::Base.delivery_method = :smtp
ActionMailer::Base.smtp_settings = {
    :enable_starttls_auto => true,
    :tls => true,
    :address => "smtp.gmail.com",
    :port => 587,
    :domain => "gmail.com",
    :authentication => "plain",
    :user_name => "YOUR USER NAME",
    :password => "YOUR PASSWORD"
}

class Notifier < ActionMailer::Base
  default :from => "YOUR FROM EMAIL"

  def deploy_notification(toEmail, fromEmail, subject, body)
    now = Time.now
    msg = "Performed a deploy operation on #{now.strftime("%m/%d/%Y")} at #{now.strftime("%I:%M %p")} to #{cap_vars.host}"

    mail(:to => cap_vars.notify_emails,
         :subject => "Deployed #{cap_vars.application} to #{cap_vars.stage}") do |format|
      format.text { render :text => msg}
      format.html { render :text => "<p>" + msg + "<\p>"}
    end
  end
end