
require "net/http"
require "json"
require "uri"
require "timeout"
require "socket"

module Pricing
  class LoyaltyHubClient
    BASE_URL = "https://loyaltyhub.co.za/api/v1/prices"

    DEFAULT_LIMIT = 10
    MAX_LIMIT = 100

    OPEN_TIMEOUT = 5
    READ_TIMEOUT = 15

    class Error < StandardError; end
    class AuthenticationError < Error; end
    class RateLimitError < Error; end
    class ApiError < Error; end
    class ConnectionError < Error; end

       def initialize(api_key: ENV["LOYALTYHUB_API_KEY"], http_class: Net::HTTP)
      @api_key = api_key.to_s.strip
      @http_class = http_class

      raise AuthenticationError, "Loyalty Hub API key is missing" if @api_key.blank?
    end

    def search(search:, limit: DEFAULT_LIMIT, offset: 0)
      query = search.to_s.strip

      raise ArgumentError, "Search term is required" if query.blank?

      limit = Integer(limit)
      offset = Integer(offset)

      raise ArgumentError, "Limit must be between 1 and #{MAX_LIMIT}" unless (1..MAX_LIMIT).cover?(limit)
      raise ArgumentError, "Offset cannot be negative" if offset.negative?

      uri = URI(BASE_URL)
      uri.query = URI.encode_www_form(
        search: query,
        limit: limit,
        offset: offset
      )

      request = Net::HTTP::Get.new(uri)
      request["Authorization"] = "Bearer #{@api_key}"
      request["Accept"] = "application/json"

      response = perform_request(uri, request)

      handle_response(response)
    rescue ArgumentError, AuthenticationError, RateLimitError, ApiError
      raise
    rescue TypeError
      raise ArgumentError, "Limit and offset must be valid integers"
    end

    private

       def perform_request(uri, request)
      @http_class.start(
        uri.host,
        uri.port,
        use_ssl: true,
        open_timeout: OPEN_TIMEOUT,
        read_timeout: READ_TIMEOUT
      ) do |http|
        http.request(request)
      end
    rescue Net::OpenTimeout, Net::ReadTimeout, Timeout::Error, SocketError, SystemCallError => error
      raise ConnectionError, "Could not connect to Loyalty Hub: #{error.class}"
    end

    def handle_response(response)
      case response.code.to_i
      when 200..299
        begin
          JSON.parse(response.body)
        rescue JSON::ParserError
          raise ApiError, "Loyalty Hub returned invalid JSON"
        end
      when 401, 403
        raise AuthenticationError, "Loyalty Hub rejected the API key"
      when 429
        raise RateLimitError, "Loyalty Hub rate limit exceeded"
      else
        raise ApiError, "Loyalty Hub returned HTTP #{response.code}"
      end
    end
  end
end
