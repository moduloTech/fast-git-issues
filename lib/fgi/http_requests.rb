# @author Matthieu Gourvénec <matthieu.gourvenec@gmail.com>
module Fgi
  module HttpRequests

    # Generic method to GET requests
    # @param url [String] the given Git service API url for GET request
    # @param headers [Hash] the headers to set for the request
    # @return [String] the received response from the Git service API
    def get(url:, headers: nil)
      http_request(verb: :get, url: url, headers: headers)
    end

    # Generic method to POST requests
    # @param url [String] the given Git service API url for POST request
    # @param headers [Hash] the headers to set for the request
    # @param body [Hash] the body to set for the request
    # @return [String] the received response from the Git service API
    def post(url:, headers: nil, body: nil)
      http_request(verb: :post, url: url, headers: headers, body: body)
    end

    private

    # Generic method for HTTP requests
    # @param url [String] the given Git service API url for a HTTP request
    # @param headers [Hash] the headers to set for the request
    # @param body [Hash] the body to set for the request
    # @return [String] the received response from the Git service API
    def http_request(verb:, url:, headers: nil, body: nil)
      is_https = url.start_with?('https')
      uri = URI.parse(url)

      req = case verb
            when :get
              Net::HTTP::Get.new(url)
            when :post
              Net::HTTP::Post.new(url)
            end

      # Set headers if given
      headers.each { |k, v| req[k] = v } unless headers.nil?
      # Set body if given
      req.body = body.to_json unless body.nil?

      res = Net::HTTP.start(uri.host, uri.port, use_ssl: is_https) do |http|
        http.request(req)
      end

      if res.code == '200'
        { status: '200', body: JSON.parse(res.body) }
      else
        { status: res.code, body: res.body }
      end
    end

  end
end
