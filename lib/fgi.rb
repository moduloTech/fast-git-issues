# @author Matthieu Gourvénec <matthieu.gourvenec@gmail.com>
module Fgi

  require 'net/http'
  require 'optparse'
  require 'json'
  require 'yaml'
  require 'uri'
  require 'cgi'

  require_relative 'fgi/git_services/gitlab'
  require_relative 'fgi/http_requests'
  require_relative 'fgi/tokens'
  require_relative 'fgi/configuration'
  require_relative 'fgi/git_service'

  # Add FGI user's current issues to the gitignore
  if `cat .gitignore | grep '.current_issues.fgi.yml'`.empty?
    File.open('.gitignore', 'a') { |f| f.write("\n.current_issues.fgi.yml") }
  end

  ISSUES = YAML.load_file('.current_issues.fgi.yml') if File.exist?('.current_issues.fgi.yml')
  # Define const variables if fgi config files exists
  # otherwise ask for configuration
  if File.exist?('.config.fgi.yml')
    CONFIG = YAML.load_file('.config.fgi.yml')
    git_service = CONFIG[:git_service_class].new
    if File.exist?("#{Dir.home}/.tokens.fgi.yml")
      TOKEN = YAML.load_file("#{Dir.home}/.tokens.fgi.yml")[git_service.to_sym][CONFIG[:url]]
    end
  end

  def self.configured?
    return if File.exist?('.config.fgi.yml')
    puts "\nThere is no FGI configuration file on this project. Please run 'fgi config'.\n\n"
    exit!
  end

end
