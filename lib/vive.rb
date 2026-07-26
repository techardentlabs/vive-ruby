# frozen_string_literal: true

require "json"
require "net/http"
require "openssl"
require "uri"

# Official Ruby client for the Vive messaging API.
module Vive
  DEFAULT_BASE_URL = "https://app.getvive.ai"

  # Every non-2xx response from the API.
  class Error < StandardError
    attr_reader :status, :fields, :request_id

    def initialize(status, message, fields = {}, request_id = nil)
      super(message)
      @status = status
      @fields = fields || {}
      @request_id = request_id
    end

    # Retrying this exact request may succeed.
    def retryable?
      status == 429 || status >= 500
    end

    def code
      fields["reason"]
    end
  end

  class AuthError < Error; end
  class RateLimitError < Error; end
  class ValidationError < Error; end

  class Client
    def initialize(api_key: nil, base_url: nil, timeout: 30, max_retries: 2)
      @api_key = api_key || ENV["VIVE_API_KEY"]
      if @api_key.nil? || @api_key.empty?
        raise ArgumentError, "Vive: an API key is required — pass api_key: or set VIVE_API_KEY."
      end

      @base_url = (base_url || ENV["VIVE_BASE_URL"] || DEFAULT_BASE_URL).chomp("/")
      @timeout = timeout
      @max_retries = max_retries
    end

    # Send a free-form text message. WhatsApp only delivers these inside the 24-hour
    # service window, which opens when the contact messages you.
    def send_text(to:, text:, idempotency_key: nil)
      post("/v1/messages", { to: to, type: "text", text: text }, idempotency_key)
    end

    # Send an approved template. Deliverable at any time, in or out of the window.
    def send_template(to:, template_name:, template_language: nil, template_params: nil,
                      category: nil, idempotency_key: nil)
      body = { to: to, type: "template", templateName: template_name }
      body[:templateLanguage] = template_language if template_language
      body[:templateParams] = template_params if template_params
      body[:category] = category if category
      post("/v1/messages", body, idempotency_key)
    end

    # Send an image, video, audio clip, document, or sticker. Supply media_url (an https
    # link WhatsApp can fetch) or media_id (already uploaded to Meta).
    def send_media(to:, type:, media_url: nil, media_id: nil, caption: nil, filename: nil,
                   reply_to: nil, idempotency_key: nil)
      body = { to: to, type: type }
      body[:mediaUrl] = media_url if media_url
      body[:mediaId] = media_id if media_id
      body[:caption] = caption if caption
      body[:filename] = filename if filename
      body[:replyTo] = reply_to if reply_to
      post("/v1/messages", body, idempotency_key)
    end

    # Up to three quick-reply buttons. Each is {id:, title:}; the tapped button's id comes
    # back on the webhook as replyId — route on that, not the title.
    def send_buttons(to:, text:, buttons:, header: nil, footer: nil, idempotency_key: nil)
      body = { to: to, type: "buttons", text: text, buttons: buttons }
      body[:header] = header if header
      body[:footer] = footer if footer
      post("/v1/messages", body, idempotency_key)
    end

    # A list picker. WhatsApp allows at most ten rows across all sections.
    def send_list(to:, text:, sections:, button_text: nil, header: nil, footer: nil, idempotency_key: nil)
      body = { to: to, type: "list", text: text, sections: sections }
      body[:buttonText] = button_text if button_text
      body[:header] = header if header
      body[:footer] = footer if footer
      post("/v1/messages", body, idempotency_key)
    end

    # A message with a button that opens a URL.
    def send_cta(to:, text:, cta_url:, cta_text: nil, idempotency_key: nil)
      body = { to: to, type: "cta_url", text: text, ctaUrl: cta_url }
      body[:ctaText] = cta_text if cta_text
      post("/v1/messages", body, idempotency_key)
    end

    def send_location(to:, latitude:, longitude:, location_name: nil, location_address: nil,
                      idempotency_key: nil)
      body = { to: to, type: "location", latitude: latitude, longitude: longitude }
      body[:locationName] = location_name if location_name
      body[:locationAddress] = location_address if location_address
      post("/v1/messages", body, idempotency_key)
    end

    # React to a message. An empty emoji removes the reaction.
    def react(to:, react_to:, emoji: "")
      post("/v1/messages", { to: to, type: "reaction", reactTo: react_to, emoji: emoji }, nil)
    end

    private

    def post(path, body, idempotency_key)
      uri = URI.join("#{@base_url}/", path.sub(%r{\A/}, ""))
      last_error = nil

      (0..@max_retries).each do |attempt|
        sleep([2**(attempt - 1), 8].min + rand * 0.25) if attempt.positive?

        request = Net::HTTP::Post.new(uri)
        request["Authorization"] = "Bearer #{@api_key}"
        request["Content-Type"] = "application/json"
        request["User-Agent"] = "vive-ruby/1.0"
        request["Idempotency-Key"] = idempotency_key if idempotency_key
        request.body = JSON.generate(body)

        begin
          response = Net::HTTP.start(uri.hostname, uri.port,
                                     use_ssl: uri.scheme == "https",
                                     open_timeout: @timeout, read_timeout: @timeout) do |http|
            http.request(request)
          end
        rescue StandardError => e
          last_error = Error.new(0, "Vive: request failed — #{e.message}")
          raise last_error if attempt == @max_retries

          next
        end

        envelope = begin
          JSON.parse(response.body.to_s)
        rescue JSON::ParserError
          {}
        end

        status = response.code.to_i
        return envelope["data"] || {} if status.between?(200, 299) && envelope["success"] != false

        error = build_error(status, envelope, response["x-request-id"])
        raise error if !error.retryable? || attempt == @max_retries

        last_error = error
      end

      raise(last_error || Error.new(0, "Vive: request failed"))
    end

    def build_error(status, envelope, request_id)
      message = envelope["message"] || "Vive: request failed with status #{status}"
      fields = envelope["errors"] || {}

      case status
      when 401, 403 then AuthError.new(status, message, fields, request_id)
      when 429 then RateLimitError.new(status, message, fields, request_id)
      when 400..499 then ValidationError.new(status, message, fields, request_id)
      else Error.new(status, message, fields, request_id)
      end
    end
  end

  # Verify the X-Vive-Signature header on an incoming webhook.
  #
  # Pass the raw request body — a re-serialized hash produces different bytes and will not
  # match. Comparison is constant-time.
  def self.verify_webhook_signature(raw_body, signature_header, signing_secret)
    return false if signature_header.nil? || signing_secret.nil? || signing_secret.empty?

    expected = "sha256=#{OpenSSL::HMAC.hexdigest('SHA256', signing_secret, raw_body)}"
    OpenSSL.secure_compare(expected, signature_header)
  end

  # Verify and parse a webhook. Raises Vive::Error if the signature does not match.
  def self.parse_webhook(raw_body, signature_header, signing_secret)
    unless verify_webhook_signature(raw_body, signature_header, signing_secret)
      raise Error.new(400, "Vive: webhook signature verification failed")
    end

    JSON.parse(raw_body)
  end
end
