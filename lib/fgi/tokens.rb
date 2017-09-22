# @author Matthieu Gourvénec <gourve_m@modulotech.fr>
module Fgi
  class Tokens
    class << self

      include HttpRequests

      # @param git_service_name [String] the git service to associate a token to
      # @param token [String] the token to associate to the git service
      def create_user_tokens_file(git_service, token)
        if File.exist?("#{Dir.home}/.tokens.fgi.yml")
          tokens = YAML.load_file("#{Dir.home}/.tokens.fgi.yml")
          tokens[git_service] = token
        else
          tokens = { git_service => token }
        end
        # Shouldn't we define some access restrictions on this file ?
        File.open("#{Dir.home}/.tokens.fgi.yml", 'w') { |f| f.write(tokens.to_yaml) }
      end

      # Add a new token association for the user's fgi configuration
      # @param token [String] the token to associate to the git service
      def add_token(token)
        git_service = CONFIG[:git_service_class].new
        token = get_token(git_service) if token.nil?
        if token_valid?(git_service, token)
          create_user_tokens_file(CONFIG[:git_service], token)
          puts "\nYour #{git_service} token has been successfully added !\n\n"
        else
          puts "\nOops, seems to be an invalid token. Try again.\n\n"
          exit!
        end
      end

      # @param git_service [Class] the current project's git service class
      # @return [String] the current token associated to the project's git service
      # @return [NilClass] if there is no token associated to the project's git service
      def get_token(git_service)
        if File.exist?("#{Dir.home}/.tokens.fgi.yml")
          tokens = YAML.load_file("#{Dir.home}/.tokens.fgi.yml")
          tokens[git_service.to_sym]
        else
          puts "\nPlease enter your #{git_service} token :"
          puts '(use `fgi --help` to check how to get your token)'
          puts '-------------------------------------------------'
          begin
            token = STDIN.gets.chomp
            exit! if token == 'quit'
            return token if token_valid?(git_service, token)
            nil
          rescue Interrupt
            exit!
          end
        end
      end

      # @param git_service [Class] the current project's git service class
      # @param token [String] the token to check the validity
      # @return [Boolean] true if the token is valid, false otherwise
      def token_valid?(git_service, token)
        response = get(
          url:     git_service.routes[:projects],
          headers: { git_service.token_header => token }
        )
        response[:status] == '200'
      end

    end
  end
end
