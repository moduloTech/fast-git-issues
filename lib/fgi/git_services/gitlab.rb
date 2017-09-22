# @author Matthieu Gourvénec <matthieu.gourvenec@gmail.com>
module Fgi
  module GitServices
    class Gitlab

      attr_reader :version, :token_header, :routes

      def initialize(config: CONFIG)
        @version      = 'v4'
        @main_url     = "#{config[:url]}/api/#{@version}"
        @token_header = 'PRIVATE-TOKEN'
        @routes = {
          projects:        "#{@main_url}/projects",
          search_projects: "#{@main_url}/projects?search=",
          issues:          "#{@main_url}/projects/#{config[:project_id]}/issues",
          branches:        "#{@main_url}/projects/#{config[:project_id]}/repository/branches"
        }
      end

      def to_sym
        :gitlab
      end

      def to_s
        'Gitlab'
      end

    end
  end
end
