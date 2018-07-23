require 'hipchat'
require 'notifier'

namespace :hipchat do

  task :notify_deploy_started do
    from = fetch(:previous_revision)
    to = fetch(:current_revision)
    send_message("#{human} is deploying #{deployment_name} to #{environment_string}.", send_options)
  end

  task :notify_deploy_finished do
    if fetch(:hipchat_commit_log, false)
      if commit_logs
        logs = commit_logs.uniq
        unless logs.empty?
          client = Capistrano::Jira.client

          issueSummaries = {}

          client.Issue.jql("key in (#{logs.join(',')})", fields: [:summary]).each do |issue, key|
            issueSummaries[issue.key] = issue.summary
          end

          logs.map! do |log|
            title = issueSummaries[log]
            "#{log} #{title}"
          end
          send_options.merge!(:color => changes_message_color)
          # send_message(logs.join("<br/>"), send_options)
          send_email(
              "#{human} finished deploying #{deployment_name} to #{environment_string}.",
              logs.join("<br/>"),
              {
                host => fetch(':smtp_host'),
                port => fetch(':smtp_port'),
                user_name => fetch(':smtp_user'),
                password => fetch(':smtp_password'),
              }
          )
        end
      end
    end

    # send_options.merge!(:color => success_message_color)
    # send_message("#{human} finished deploying #{deployment_name} to #{environment_string}.", send_options)
  end

  task :notify_deploy_reverted do
    send_options.merge!(:color => failed_message_color)
    send_message("#{human} cancelled deployment of #{deployment_name} to #{environment_string}.", send_options)
  end

  def send_email(subject, body, options = {
      host => '',
      port => '',
      user_name => '',
      password => '',
      tls => true,
  })
    Notifier.deploy_notification(
        fetch(':email_from'),
        fetch(':email_to'),
        subject,
        body,
        options
    ).deliver
  end

  def send_options
    return @send_options if defined?(@send_options)
    @send_options = message_format ? {:message_format => message_format} : {}
    @send_options.merge!(:notify => message_notification)
    @send_options.merge!(:color => message_color)
    @send_options
  end

  def send_message(message, options)
    return unless enabled?

    hipchat_token = fetch(:hipchat_token)
    hipchat_room_name = fetch(:hipchat_room_name)
    hipchat_options = fetch(:hipchat_options, {})


    if hipchat_room_name.is_a?(String)
      rooms = [hipchat_room_name]
    elsif hipchat_room_name.is_a?(Symbol)
      rooms = [hipchat_room_name.to_s]
    else
      rooms = hipchat_room_name
    end

    rooms.each {|room, token|
      begin
        hipchat_client = fetch(:hipchat_client, HipChat::Client.new(token, hipchat_options))
        hipchat_client[room].send(deploy_user, message, options)
      rescue => e
        puts e.message
        puts e.backtrace
      end
    }
  end

  def enabled?
    fetch(:hipchat_enabled, true)
  end

  def environment_string
    if fetch(:stage)
      "#{fetch(:stage)} (#{environment_name})"
    else
      environment_name
    end
  end

  def deployment_name
    if fetch(:branch, nil)
      branch = fetch(:branch)
      real_revision = fetch(:real_revision)

      name = "#{application_name}/#{branch}"
      name += " (revision #{real_revision[0..7]})" if real_revision
      name
    else
      application_name
    end
  end

  def application_name
    alt_application_name.nil? ? fetch(:application) : alt_application_name
  end

  def message_color
    fetch(:hipchat_color, 'yellow')
  end

  def success_message_color
    fetch(:hipchat_success_color, 'green')
  end


  def changes_message_color
    fetch(:hipchat_changes_color, 'purple')
  end

  def failed_message_color
    fetch(:hipchat_failed_color, 'red')
  end

  def message_notification
    fetch(:hipchat_announce, false)
  end

  def message_format
    fetch(:hipchat_message_format, 'html')
  end

  def deploy_user
    fetch(:hipchat_deploy_user, 'Deploy')
  end

  def alt_application_name
    fetch(:hipchat_app_name, nil)
  end

  def human
    user = ENV['HIPCHAT_USER'] || fetch(:hipchat_human)
    user = user || if (u = %x{git config user.name}.strip) != ''
                     u
                   elsif (u = ENV['USER']) != ''
                     u
                   else
                     'Someone'
                   end
    user
  end

  def environment_name
    fetch(:hipchat_env, fetch(:rack_env, fetch(:rails_env, fetch(:stage))))
  end

  def commit_logs
    from = fetch(:previous_revision)
    to = fetch(:current_revision)

    log_hashes = []

    if from != to
      logs = `git log --no-merges --pretty=format:'%H$$%at$$%an$$%s' #{from}..#{to}`
      logs.split(/\n/).each do |log|
        ll = log.split(/\$\$/)
        log_hashes << {revision: ll[0], time: Time.at(ll[1].to_i), user: ll[2], message: ll[3]}
      end

      format = fetch(:hipchat_commit_log_format, ":message")
      time_format = fetch(:hipchat_commit_log_time_format, "%Y/%m/%d %H:%M:%S")
      message_format = fetch(:hipchat_commit_log_message_format, nil)

      log_hashes.map do |log_hash|
        if message_format
          matches = log_hash[:message].match(/#{message_format}/)
          log_hash[:message] = if matches
                                 matches[0]
                               else
                                 ''
                               end
        end
        log_hash[:time] &&= log_hash[:time].localtime.strftime(time_format)
        log_hash.inject(format) do |l, (k, v)|
          l.gsub(/:#{k}/, v.to_s)
        end
      end
    end
  end

  after 'deploy:starting', 'hipchat:notify_deploy_started'
  after 'deploy:finished', 'hipchat:notify_deploy_finished'
  if Rake::Task.task_defined? 'deploy:failed'
    after 'deploy:failed', 'hipchat:notify_deploy_reverted'
  end

end
