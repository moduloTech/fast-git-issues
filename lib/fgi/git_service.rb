# @author Matthieu Gourvénec <matthieu.gourvenec@gmail.com>
module Fgi
  class GitService
    class << self
      include HttpRequests

      def services
        services = []
        Dir.entries("#{File.dirname(__FILE__)}/git_services").each do |service|
          services << service.gsub(/.rb/, '').to_sym unless %w(. ..).include?(service)
        end
        services
      end

      def create_issue(title:, description: '')
        git_service = CONFIG[:git_service_class].new(CONFIG)

        headers = { git_service.token_header => TOKEN, 'Content-Type': 'application/json' }
        url_with_querystring = "#{git_service.routes[:issues]}?title=#{URI.encode(title)}&description=#{URI.encode(description)}"

        response = post(url: url_with_querystring, headers: headers)

        post_issue_display(JSON.parse(response[:body]))
      end

      private

      def post_issue_display(response)
        if !response['iid'].nil?
          puts 'Your issue has been successfully created.'
          puts 'To view it, please follow the link bellow :'
          puts "\n#{CONFIG[:url]}/#{CONFIG[:project_slug]}/issues/#{response['iid']}"
          puts "\nThank you for using Fast Gitlab Issues!"
        else
          puts %q(Your issue couldn't be created. Check your FGI configuration.)
        end
      end

    end
  end
end
