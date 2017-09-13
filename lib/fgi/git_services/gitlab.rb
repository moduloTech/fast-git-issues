# @author Matthieu Gourvénec <matthieu.gourvenec@gmail.com>
module Fgi
  module GitServices
    class Gitlab

      def initialize(config: CONFIG)
        @version = 'v4'
        @token_header = 'PRIVATE-TOKEN'
        @routes = {
                     projects: "#{config[:url]}/api/#{@version}/projects",
                     search_projects: "#{config[:url]}/api/#{@version}/projects?search=",
                     issues: "#{config[:url]}/api/#{@version}/projects/#{config[:project_id]}/issues",
                     branches: "#{config[:url]}/api/#{@version}/projects/#{config[:project_id]}/branches"
                   }
      end

      def version
        @version
      end

      def token_header
        @token_header
      end

      def routes
        @routes
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
