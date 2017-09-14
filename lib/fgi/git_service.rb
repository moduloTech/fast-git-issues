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

      def create_issue(title: title, estimation: nil)
        create_new_branch(title)
        git_service = CONFIG[:git_service_class].new
        title = get_issue_title if title.nil?
        description = get_issue_description

        headers = { git_service.token_header => TOKEN, 'Content-Type' => 'application/json' }
        url_with_querystring = "#{git_service.routes[:issues]}?title=#{URI.encode(title)}&description=#{URI.encode(description)}"

        response = post(url: url_with_querystring, headers: headers)
        response_body = JSON.parse(response[:body])

        post_issue_display(response_body)

        unless estimation.nil?
          # Since GitLab version isn't up to date, we should be able to add estimations in issues comments (/estimate)
          url_with_querystring = "#{git_service.routes[:issues]}/#{response_body['iid']}/time_estimate?duration=#{estimation}"
          response = post(url: url_with_querystring, headers: headers)
          # GitLab sucks sometimes... This API is an example
          begin
            response_body = JSON.parse(response[:body])
          rescue Exception => e
            response_body = response[:body]
          end

          post_estimation_display(response_body, estimation)
        end
      end

      def create_new_branch(issue_title)
        branch_name = snakecase(issue_title)
        unless %x(git status -s).empty?
          puts "\nThere are unsaved changes on your current branch :\n\n"
          system('git diff')
          begin

            puts "\nDo you want to COMMIT theses changes ? (y/n)"
            input = STDIN.gets.chomp
            if %w[y yes].include?(input)
              commit_changes
            else
              stash_changes
            end

          rescue Interrupt => int
            puts %q"Why did you killed me ? :'("
            exit!
          end
          %x(git checkout #{CONFIG[:default_branch]}) # Be sure to be on the default branch.
          from = %x(git branch | grep '*').gsub('* ', '').chomp
          %x(git pull origin HEAD) # Be sure to get the remote changes locally.
          %x(git checkout -b #{branch_name}) # Create the new branch.
          to = %x(git branch | grep '*').gsub('* ', '').chomp
          puts "\nYou are now working on branch #{to} created from #{from} !"
        end
      end

      private

      def get_issue_description
        puts "\nWrite your issue description right bellow (save and quit with CTRL+D) :"
        puts "-----------------------------------------------------------------------\n\n"
        begin
          STDIN.read
        rescue Interrupt => int
          puts %q"Why did you killed me ? :'("
          exit!
        end
      end

      def get_issue_title
        puts "\nWhat if your issue title :"
        puts "--------------------------\n\n"
        begin
          STDIN.gets.chomp
        rescue Interrupt => int
          puts %q"Why did you killed me ? :'("
          exit!
        end
      end

      def post_issue_display(response)
        unless response['iid'].nil?
          puts 'Your issue has been successfully created.'
          puts 'To view it, please follow the link bellow :'
          puts "\n#{CONFIG[:url]}/#{CONFIG[:project_slug]}/issues/#{response['iid']}"
        else
          puts %q(Your issue couldn't be created. Check your FGI configuration.)
        end
      end

      def post_estimation_display(response, estimation)
        if response['human_time_estimate'].nil?
          puts "\nWe weren't able to save your estimation."
          puts "You'll have to do it manually on #{CONFIG[:git_service].capitalize}."
        else
          puts "\nYou have #{estimation} to resolve this issue. Good luck ;)"
        end
      end

      def commit_changes
        puts 'Enter your commit message :'
        commit_message = STDIN.gets.chomp
        %x(git add .)
        %x(git commit -am '#{commit_message}')
        puts 'Your changes have been commited !'
      end

      def stash_changes
        %x(git add .)
        %x(git stash)
        puts "\nYour changes have been stashed."
        puts 'We will let you manually `git stash pop` to get your work back if needed.'
      end

      def snakecase(string)
        string.gsub(/::/, '/').
               gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
               gsub(/([a-z\d])([A-Z])/,'\1_\2').
               tr('-', '_').
               tr(' ', '_').
               downcase
      end

    end
  end
end
