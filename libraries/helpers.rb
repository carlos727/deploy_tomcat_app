require 'net/smtp'
require 'json'
require 'net/http'
require 'uri'

include Chef::Mixin::PowershellOut

#
# Define general functions and methods
#
module Tool
  module_function

  def unindent(string)
    first = string[/\A\s*/]
    string.gsub /^#{first}/, ''
  end

  def send_email(to, mailtext)
    smtp = Net::SMTP.new('smtp.office365.com', 587)
    smtp.enable_starttls_auto
    smtp.start('smtp.office365.com', 'barcoder@redsis.com', 'Orion2015', :login)
    smtp.send_message(mailtext, 'barcoder@redsis.com', to)
    smtp.finish
  end

  def simple_email(to, subject, message)
    message = <<-MESSAGE
      From: Chef Reporter <barcoder@redsis.com>
      To: <#{to}>
      Subject: #{subject}

      #{message}
    MESSAGE

    mailtext = unindent message

    send_email to, mailtext
  end

  def attached_email(to, subject, message)
    filename = "C:\\chef\\log-#{Chef.run_context.node.name}"
    encodedcontent = [File.read(filename)].pack("m") # Read a file and encode it into base64 format
    marker = 'AUNIQUEMARKER'

    header = <<-HEADER
      From: Chef Reporter <barcoder@redsis.com>
      To: <#{to}>
      Subject: #{subject}
      MIME-Version: 1.0
      Content-Type: multipart/mixed; boundary=#{marker}
      --#{marker}
    HEADER

    body = <<-BODY
      Content-Type: text/plain
      Content-Transfer-Encoding:8bit

      #{message}
      --#{marker}
    BODY

    attached = <<-ATTACHED
      Content-Type: multipart/mixed; name=\"#{filename}\"
      Content-Transfer-Encoding:base64
      Content-Disposition: attachment; filename="#{filename}"

      #{encodedcontent}
      --#{marker}--
    ATTACHED

    mailtext = unindent header + body + attached

    send_email to, mailtext
  end

end

#
# Define functions and methods related to an Url
#
module Url
  module_function

  def web_scraping(url, username, password)
    require 'mechanize'

    agent = Mechanize.new
    agent.user_agent_alias = 'Windows Chrome'

    unless username.nil?
      agent.add_auth(url, username, password)
    end

    res = agent.get(url)
    return (res.body).to_s
  end

  def is_reachable?(url)
    require 'mechanize'

    sw = true
    agent = Mechanize.new
    agent.user_agent_alias = 'Windows Chrome'
    agent.agent.http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    tries = 3
    cont = 0

    begin
    	agent.read_timeout = 5 #set the agent time out
    	page = agent.get(url)
  	rescue
      cont += 1
      unless (tries -= 1).zero?
        Chef::Log.warn("Verifying if url #{url} is reachable (#{cont}/3) failed, try again in 1 minutes...")
        agent.shutdown
        agent = Mechanize.new { |agent| agent.user_agent_alias = 'Windows Chrome'}
        agent.request_headers
        sleep(60)
        retry
      else
        Chef::Log.error("The url #{url} isn't available.")
        sw = false
      end
    else
      sw = true
    ensure
      agent.history.pop()   #delete this request in the history
    end

    return sw
  end

  def fetch(url)
    resp = Net::HTTP.get_response(URI.parse(url))
    data = resp.body
    return JSON.parse(data)
  end

end

#
# Define functions and methods related to Tomcat Service.
#
module TomcatService
  module_function

  def get_war_folder
    if File.directory?('C:\Program Files (x86)\Apache Software Foundation\Tomcat 7.0\webapps')
      return 'C:\Program Files (x86)\Apache Software Foundation\Tomcat 7.0\webapps'
    else
      return 'C:\Program Files\Apache Software Foundation\Tomcat 7.0\webapps'
    end
  end

  def is_running?
    tomcat = powershell_out!("(Get-Service Tomcat7).Status -eq \'Running\'")

    if tomcat.stdout[/True/]
      return true
    else
      return false
    end
  end

  def is_stop?
    tomcat = powershell_out!("(Get-Service Tomcat7).Status -eq \'Stopped\'")

    if tomcat.stdout[/True/]
      return true
    else
      return false
    end
  end

  def wait_start
    require 'mechanize'

    if is_running?
      agent = Mechanize.new
      agent.user_agent_alias = 'Windows Chrome'

    	begin
      	agent.read_timeout = 5 #set the agent time out
      	page = agent.get('http://localhost:8080')
        Chef::Log.info('Tomcat7 Started')
    	rescue
    		Chef::Log.info('Waiting 2.5 minutes for Tomcat7 to continue...')
    		agent.shutdown
    		agent = Mechanize.new { |agent| agent.user_agent_alias = 'Windows Chrome'}
    		agent.request_headers
    		sleep(150)
    		retry
      ensure
        agent.history.pop()   #delete this request in the history
      end
    end
  end

  def wait_stop
    while !is_stop? do
      Chef::Log.info('Waiting 1 minutes for Tomcat7 to continue...')
      sleep(60)
    end
    Chef::Log.info('Tomcat7 stopped !')
  end

end

#
# Define functions and methods related to Tomcat Manager application.
#
module TomcatManager
  module_function

  def session_list(username, password)
    session_message = Url.web_scraping('http://localhost:8080/manager/text/list', username, password)
    sessions = []

    session_message.each_line do |line|
      session = line.split(':')
      sessions.push(session)
    end

    expire_app_sessions('manager', username, password)
    return sessions
  end

  def active_sessions?(username, password)
    if TomcatService.is_running?
      sessions = session_list(username, password)
      sw = false

      sessions.each do |session|
        if session.first.start_with?("/") && !session.first.eql?("/manager") && session[2].to_i > 0
          sw = true
        end
      end

      return sw
    else
      return false
    end
  end

  def run_app(app, username, password)
    require 'mechanize'

    app_status = App.status?(app, username, password)
    if app_status.first && app_status.last.eql?('stopped')
      agent = Mechanize.new
      agent.user_agent_alias = 'Windows Chrome'
      agent.add_auth("http://localhost:8080/manager/text/start?path=/#{app}", username, password)
      page = agent.get("http://localhost:8080/manager/text/start?path=/#{app}")

      begin
        Chef::Log.info("Waiting 2 minutes while starting #{app} to continue...")
        sleep(120)
        status = App.status?(app, username, password)
      end while status.last.eql?('stopped')

      Chef::Log.info("#{app} Running !")
    else
      Chef::Log.warn("Couldn't run #{app} !")
    end
  end

  def stop_app(app, username, password)
    require 'mechanize'

    app_status = App.status?(app, username, password)
    if app_status.first && app_status.last.eql?('running')
      agent = Mechanize.new
      agent.user_agent_alias = 'Windows Chrome'
      agent.add_auth("http://localhost:8080/manager/text/stop?path=/#{app}", username, password)
      page = agent.get("http://localhost:8080/manager/text/stop?path=/#{app}")

      begin
        Chef::Log.info("Waiting 2 minutes while stopping #{app} to continue...")
        sleep(120)
        status = App.status?(app, username, password)
      end while status.last.eql?('running')

      Chef::Log.info("#{app} Stopped !")
    else
      Chef::Log.warn("Couldn't stop #{app} !")
    end
  end

  def undeploy_app(app, username, password)
    require 'mechanize'

    app_status = App.status?(app, username, password)
    if app_status.first
      sw = true
      agent = Mechanize.new
      agent.user_agent_alias = 'Windows Chrome'
      tries = 3
      cont = 0

      begin
        agent.add_auth("http://localhost:8080/manager/text/undeploy?path=/#{app}", username, password)
        page = agent.get("http://localhost:8080/manager/text/undeploy?path=/#{app}")
      rescue
        cont += 1
        unless (tries -= 1).zero?
          Chef::Log.warn("Undeploy #{app} (#{cont}/3) failed, try again in 1 minutes...")
          agent.shutdown
          agent = Mechanize.new { |agent| agent.user_agent_alias = 'Windows Chrome'}
          agent.request_headers
          sleep(60)
          retry
        else
          Chef::Log.error("Could not execute undeploy #{app}.")
          sw = false
        end
      else
        sw = true
      ensure
        agent.history.pop()   #delete this request in the history
      end

      if sw
        i = 0
        begin
          Chef::Log.info("Waiting 2 minutes while undeploying #{app} to continue...")
          i += 1
          sleep(120)
          status = App.status?(app, username, password)
        end while status.first && i < 5

        app_status = App.status?(app, username, password)
        if app_status.first
          agent.shutdown
          sleep(60)
          agent = Mechanize.new { |agent| agent.user_agent_alias = 'Windows Chrome'}

          begin
            agent.add_auth("http://localhost:8080/manager/text/undeploy?path=/#{app}", username, password)
            page = agent.get("http://localhost:8080/manager/text/undeploy?path=/#{app}")
          rescue
            Tool.simple_email(
              'cbeleno@redsis.com',
              "Chef Undeploy #{app} on Node #{Chef.run_context.node.name}",
              'Needing a manual adjustment !'              
            )
          end

          i = 0
          begin
            Chef::Log.info("Waiting 1.5 minutes more while undeploying #{app} to continue...")
            i += 1
            sleep(90)
            status = App.status?(app, username, password)
          end while status.first && i < 4
        end

        app_status = App.status?(app, username, password)
        unless app_status.first
          Chef::Log.info("Eva Undeployed !")
          return true
        else
          Chef::Log.info("Could not undeploy Eva.")
          return false
        end
      else
        return false
      end
    end
  end

  def deploy_app(app, username, password)
    require 'mechanize'

    app_status = App.status?(app, username, password)
    unless app_status.first
      url = URI.parse(URI.encode("http://localhost:8080/manager/text/deploy?path=/#{app}&war=file:C:\\chef\\New_War\\#{app}.war"))
      sw = true
      agent = Mechanize.new
      agent.user_agent_alias = 'Windows Chrome'
      tries = 3
      cont = 0

      begin
        agent.add_auth(url, username, password)
        page = agent.get(url)
      rescue
        cont += 1
        unless (tries -= 1).zero?
          Chef::Log.warn("Deploy #{app} (#{cont}/3) failed, try again in 1 minutes...")
          agent.shutdown
          agent = Mechanize.new { |agent| agent.user_agent_alias = 'Windows Chrome'}
          agent.request_headers
          sleep(60)
          retry
        else
          Chef::Log.error("Could not execute deploy #{app}.")
          sw = false
        end
      else
        sw = true
      end

      if sw
        i = 0
        begin
          Chef::Log.info("Waiting 2 minutes while deploying #{app} to continue...")
          i += 1
          sleep(120)
          status = App.status?(app, username, password)
        end until (status.first && status.last.eql?('running')) || i > 5

        agent.shutdown
        agent.history.pop   #delete this request in the history

        app_status = App.status?(app, username, password)
        if !app_status.first || app_status.last.eql?('stopped')
          Tool.simple_email(
            'cbeleno@redsis.com',
            "Chef Deploy #{app} on Node #{Chef.run_context.node.name}",
            'Needing a manual adjustment !',
          )
          sleep(60)

          i = 0
          begin
            Chef::Log.info("Waiting 2 minutes while deploying #{app} to continue...")
            i += 1
            sleep(120)
            status = App.status?(app, username, password)
          end until (status.first && status.last.eql?('running')) || i > 5
        end

        app_status = App.status?(app, username, password)
        if app_status.first && status.last.eql?('running')
          Chef::Log.info("#{app} Deployed !")
          return true
        else
          Chef::Log.info("Could not deploy #{app}.")
          return false
        end
      else
        return false
      end
    end
  end

  def expire_app_sessions(app, username, password)
    require 'mechanize'

    agent = Mechanize.new
    agent.user_agent_alias = 'Windows Chrome'
    agent.add_auth("http://localhost:8080/manager/text/expire?path=/#{app}&idle=0", username, password)
    page = agent.get("http://localhost:8080/manager/text/expire?path=/#{app}&idle=0")
  end

end

#
# Define functions and methods related to a tomcat application
#
module App
  module_function

  def status?(app, username, password)
    if TomcatService.is_running?
      sessions = TomcatManager.session_list(username, password)
      exist = false
      status = ''

      sessions.each do |session|
        if session.first.eql?("/#{app}")
          exist = true
          status = session[1]
        end
      end

      return [exist, status]
    else
      return [false, '']
    end
  end

  def is_current_version?(app, username, password, war_url, app_version_url, version_patterm, version_from_url)
  	sw = false
  	if status?(app, username, password).first
      if Url.is_reachable?(app_version_url)
        if version_from_url
          version = app_version_url
        else
          json_object = Url.fetch(app_version_url)
          version = json_object['version']
        end
        unless version[version_patterm].nil?
          current_version = version[version_patterm]
          new_version = war_url[version_patterm]
          sw = current_version.eql?(new_version)
        end
      else
        Chef::Log.warn("Could not determine the version of Eva.")
      end
  	end
  	return sw
  end

end

Chef::Recipe.send(:include, Tool)
Chef::Recipe.send(:include, Url)
Chef::Recipe.send(:include, TomcatService)
Chef::Recipe.send(:include, TomcatManager)
Chef::Recipe.send(:include, App)
