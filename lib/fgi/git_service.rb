# @author Matthieu Gourvénec <matthieu.gourvenec@gmail.com>
module Fgi
  class GitService
    class << self

      include HttpRequests

      # @return [Array<String>] an array containing all the git services available.
      def services
        services = []
        Dir.entries("#{File.dirname(__FILE__)}/git_services").each do |service|
          services << service.gsub(/.rb/, '').to_sym unless %w[. ..].include?(service)
        end
        services
      end

      # All the process initiated by the issue creation
      #   => Create issue
      #   => Create a new branch from the default one
      #   => Set the issue estimation time
      # @param title [String] the issue title
      # @param options [Hash] the options given by the user in the command line
      def new_issue(title:, options: {})
        git_service = CONFIG[:git_service_class].new
        title = get_issue_title if title.nil?
        response = create_issue(title: title, git_service: git_service)

        if CONFIG[:default_branch].nil?
          puts "\n/!\\ FGI IS NOT UP-TO-DATE /!\\"
          puts 'We are not able to create and switch you to the new branch.'
          puts 'Delete .config.fgi.yml and reconfigure fgi by running `fgi config`'
        elsif !response['iid'].nil?
          branch_name = snakify(title)
          branch_name = "#{options[:prefix]}/#{branch_name}" unless options[:prefix].nil?
          save_issue(branch: branch_name, id: response['iid'], title: response['title'].tr("'", ' ').tr('_', ''))
          create_branch(name: branch_name, from_current: options[:from_current]) unless options[:later]
          set_issue_estimation(
            issue_id:    response['iid'],
            estimation:  options[:estimate],
            git_service: git_service
          )
        end
      end

      # All the process initiated by the issue fix
      #   => Commiting with a 'Fix #<id>' message
      #   => Pushing the current branch to the remote repo
      #   => Return to the default project branch
      # @param options [Hash] the options given by the user in the command line
      def fix_issue(options)
        if ISSUES[current_branch].nil?
          puts "We could not find any issues to fix on your current branch (#{current_branch})."
          exit!
        end
        git_remote = ask_for_remote
        `git add .`
        puts "Are you sure to want to close the issue #{ISSUES[current_branch][:title]} ?"
        begin
          input = STDIN.gets.chomp
          if %w[y yes].include?(input)
            commit_message =  "Fix ##{ISSUES[current_branch][:id]}"
            commit_message += " - #{options[:fix_message]}" unless options[:fix_message].nil?
            `git commit -a --allow-empty -m '#{commit_message}'`
            `git push #{git_remote} HEAD`
            `git branch -u #{git_remote}/#{name}` # Define the upstream branch
            `git checkout #{CONFIG[:default_branch]}` # Be sure to be on the default branch.
            remove_issue(current_branch)
            puts "Congrat's ! You're now back to work on the default branch (#{CONFIG[:default_branch]})"
          end
        rescue Interrupt
          puts %q"Why did you killed me ? :'("
          exit!
        end
      end

      def current_branch
        `git branch | grep '*'`.gsub('* ', '').chomp
      end

      # TODO, Make sure it works for all git services
      # The method to set the estimation time to resolve the issue
      # @param issue_id [Integer] the issue id to set its estimation time
      # @param estimation [String] the estimation time given by the user
      # @param git_service [Class] the git service class to use for this project
      def set_issue_estimation(issue_id:, estimation:, git_service:)
        return if estimation.nil?
        # Since GitLab version isn't up to date, we should be able
        #   to add estimations in issues comments (/estimate)
        url_with_querystring = "#{git_service.routes[:issues]}/#{issue_id}/time_estimate?duration=#{estimation}"
        response = post(url: url_with_querystring, headers: headers)
        # GitLab sucks sometimes... This API is an example
        begin
          response_body = JSON.parse(response[:body])
        rescue Exception
          response_body = response[:body]
        end
        post_estimation_display(response_body['human_time_estimate'], estimation)
      end

      private

      def ask_for_remote
        remotes = `git remote`.split("\n")
        return remotes.first if remotes.count == 1

        puts "\nHere are your remotes :"
        remotes.each_with_index do |remote, index|
          puts "#{index + 1} - #{remote}"
        end

        begin
          puts "\nPlease insert the number of the remote to use :"
          puts '-----------------------------------------------'
          input = STDIN.gets.chomp
          exit! if input == 'quit'
          input = input.to_i
          if (1..remotes.count).cover?(input)
            remotes[input-1]
          else
            puts "\nSorry, the option is out of range. Try again :"
            ask_for_remote
          end
        rescue Interrupt
          puts %q"Why did you killed me ? :'("
          exit!
        end
      end

      # Save the current user's FGI created issue in the gitignored file 'current_issue.fgi.yml'
      # @param id [Integer] the current issue id
      # @param title [String] the current issue name
      def save_issue(branch:, id:, title:)
        if File.exist?('.current_issues.fgi.yml')
          issues = YAML.load_file('.current_issues.fgi.yml')
          issues[branch] = { id: id, title: title }
        else
          issues = {
            branch => {
              id:    id,
              title: title
            }
          }
        end
        # Shouldn't we define some access restrictions on this file ?
        File.open('.current_issues.fgi.yml', 'w') { |f| f.write(issues.to_yaml) }
      end

      def remove_issue(branch)
        issues = YAML.load_file('.current_issues.fgi.yml')
        issues.delete(branch) unless ISSUES[branch].nil?
        File.open('.current_issues.fgi.yml', 'w') { |f| f.write(issues.to_yaml) }
      end

      # TODO, Make sure it works for all git services
      # The method used to create issues
      # @param title [String] the issue title
      # @param git_service [Class] the git service class to use for this project
      # @return [Boolean] true if the issue has been created, false otherwise
      def create_issue(title:, git_service:)
        description = get_issue_description

        headers = { git_service.token_header => TOKEN, 'Content-Type' => 'application/json' }
        url_with_querystring = "#{git_service.routes[:issues]}?title=#{CGI.escape(title)}&description=#{CGI.escape(description)}"

        response = post(url: url_with_querystring, headers: headers)
        response_body = JSON.parse(response[:body])

        post_issue_display(response_body['iid'])
        response_body
      end

      # The method used to create branches
      # @param name [String] the branch name
      def create_branch(name:, from_current:)
        from = if from_current
                 current_branch
               else
                 CONFIG[:default_branch]
               end
        check_status
        git_remote = ask_for_remote
        `git checkout #{from}` # Be sure to be on the default or specified branch.
        `git pull #{git_remote} HEAD` # Be sure to get the remote changes locally.
        `git checkout -b #{name}` # Create the new branch.
        puts "\nYou are now working on branch #{current_branch} created from #{from} !"
      end

      # The method used to get the issue description
      # @return [String] the issue description
      def get_issue_description
        puts "\nWrite your issue description right bellow (save and quit with CTRL+D) :"
        puts "-----------------------------------------------------------------------\n\n"
        begin
          STDIN.read
        rescue Interrupt
          puts %q"Why did you killed me ? :'("
          exit!
        end
      end

      # The method used to get the issue title if not given the first time
      # @return [String] the issue title
      def get_issue_title
        puts "\nWhat is your issue title :"
        puts "--------------------------\n\n"
        begin
          STDIN.gets.chomp
        rescue Interrupt
          puts %q"Why did you killed me ? :'("
          exit!
        end
      end

      # The display method to let the user know
      #   if the issue has correctly been created
      # @param issue_id [Integer] the id of the created issue
      def post_issue_display(issue_id)
        if !issue_id.nil?
          puts 'Your issue has been successfully created.'
          puts 'To view it, please follow the link bellow :'
          puts "\n#{CONFIG[:url]}/#{CONFIG[:project_slug]}/issues/#{issue_id}"
        else
          puts %q(Your issue couldn't be created. Check your FGI configuration.)
        end
      end

      # The display method to let the user know if the
      #   estimation time has correctly been set on the issue
      # @param response_estimation [String] the estimation time response from the git service
      # @param estimation [String] the estimation time given by the user
      def post_estimation_display(response_estimation, estimation)
        if response_estimation.nil?
          puts "\nWe weren't able to save your estimation."
          puts "You'll have to do it manually on #{CONFIG[:git_service].capitalize}."
        else
          puts "\nYou have #{estimation} to resolve this issue. Good luck ;)"
        end
      end

      # The method used to commit the user's local changes
      def commit_changes
        puts 'Enter your commit message :'
        commit_message = STDIN.gets.chomp
        `git add .`
        `git commit -am '#{commit_message}'`
        puts 'Your changes have been commited !'
      end

      # The method used to stash the user's local changes
      def stash_changes
        `git add .`
        `git stash`
        puts "\nYour changes have been stashed."
        puts "We will let you manually git stash pop to get your work back if needed.\n"
      end

      # The method used to check if there are local changes and to
      #   ask the user if he want to commit or stash theses changes
      def check_status
        return if `git status -s`.empty?
        begin
          puts "\nThere are unsaved changes on your current branch."
          puts 'Do you want to see them ? (y/n)'
          puts '-------------------------------'
          input = STDIN.gets.chomp
          system('git diff') if %w[y yes].include?(input)

          puts "\nDo you want to COMMIT theses changes ? (y/n)"
          puts '--------------------------------------------'
          input = STDIN.gets.chomp
          if %w[y yes].include?(input)
            commit_changes
          else
            stash_changes
          end
        rescue Interrupt
          puts %q"Why did you killed me ? :'("
          exit!
        end
      end

      # The method used to snakify strings
      # @param string [String] the string to snakify
      # @return [String] the snakified string
      def snakify(string)
        string.gsub(/::/, '/')
              .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
              .gsub(/([a-z\d])([A-Z])/, '\1_\2')
              .tr('-', '_')
              .tr(' ', '_')
              .tr("'", '_')
              .downcase
      end

    end
  end
end
