module Middleware
  class RequestBodySizeLimit
    MAX_JSON_BODY_SIZE = 5 * 1024 * 1024
    IMPORT_PATH = "/api/v1/retailer_feeds/import"

    def initialize(app)
      @app = app
    end

    def call(env)
      request = Rack::Request.new(env)

      if request.post? &&
         request.path == IMPORT_PATH &&
         request.media_type == "application/json"

       content_length = request.content_length.to_i

if content_length > MAX_JSON_BODY_SIZE
          return payload_too_large
        end

        input = request.body
        body = input.read(MAX_JSON_BODY_SIZE + 1)

        if body.bytesize > MAX_JSON_BODY_SIZE
          return payload_too_large
        end

        input.rewind
      end

                @app.call(env)
    rescue ActionView::Template::Error => error
      raise unless error.cause.is_a?(
        ActionDispatch::Http::Parameters::ParseError
      )

      invalid_json
    rescue ActionDispatch::Http::Parameters::ParseError
      invalid_json
    end

    private

        def invalid_json
      body = {
        error: "Invalid JSON request body"
      }.to_json

      [
        400,
        {
          "content-type" => "application/json; charset=utf-8",
          "content-length" => body.bytesize.to_s
        },
        [body]
      ]
    end

    def payload_too_large
      body = {
        error: "JSON request body cannot exceed 5 MB"
      }.to_json

      [
        413,
        {
          "content-type" => "application/json; charset=utf-8",
          "content-length" => body.bytesize.to_s
        },
        [body]
      ]
    end
  end
end