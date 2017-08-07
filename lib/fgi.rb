# @author Matthieu Gourvénec <matthieu.gourvenec@gmail.com>
module Fgi

  require 'net/http'
  require 'optparse'
  require 'json'
  require 'yaml'
  require 'uri'

  require_relative 'fgi/git_services/gitlab'
  require_relative 'fgi/http_requests'
  require_relative 'fgi/configuration'
  require_relative 'fgi/git_service'

  # Define const variables if fgi config files exists
  # otherwise ask for configuration
  if File.exists?('.config.fgi.yml')
    CONFIG = YAML.load_file('.config.fgi.yml')
    git_service = CONFIG[:git_service_class].new(CONFIG)
    if File.exists?("#{Dir.home}/.tokens.fgi.yml")
      TOKEN = YAML.load_file("#{Dir.home}/.tokens.fgi.yml")[git_service.to_sym]
    end
  end
end
