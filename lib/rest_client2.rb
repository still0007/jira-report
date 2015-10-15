require 'rest_client'

module RestClient2
  include RestClient

  def self.get(url, headers={}, &block)
    Request.execute(:method => :get, :url => url, :headers => headers,
                    :timeout => $timeout, :open_timeout => $open_timeout, &block)
  end

  def self.post(url, payload, headers={}, &block)
    Request.execute(:method => :post, :url => url, :payload => payload, :headers => headers,
                    :timeout => $timeout, :open_timeout => $open_timeout, &block)
  end

  def self.put(url, payload, headers={}, &block)
    RestClient.put(url, payload, headers) do |response, request, result, &block|
      if [301, 302, 307].include? response.code
         response.follow_redirection(request, result, &block)
      else
         response.return!(request, result, &block)
      end
    end
  end
end