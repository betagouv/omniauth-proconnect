# frozen_string_literal: true

require "faraday"
require "omniauth"
require "json/jwt"

require_relative "proconnect/version"

module OmniAuth
  module Strategies
    class Proconnect
      class Error < StandardError; end

      include OmniAuth::Strategy

      option :name, "proconnect"
      option :client_id
      option :client_secret
      option :proconnect_domain
      option :redirect_uri
      option :post_logout_redirect_uri
      option :scope, "openid email given_name usual_name"

      def setup_phase
        discover_endpoint!
      end

      def request_phase
        redirect(authorization_uri)
      end

      def callback_phase
        verify_state!(request.params["state"])

        exchange_authorization_code!(request.params["code"])
          .then { |response| store_tokens!(response) }
          .then { get_userinfo! }
          .then { |response| @userinfo = JSON::JWT.decode(response.body, :skip_verification) }
          .then { super }
      end

      def other_phase
        if on_logout_path?
          engage_logout!
        else
          call_app!
        end
      end

      # userinfo-operating DSL from OmniAuth
      uid do
        @userinfo["sub"]
      end

      info do
        {
          email: @userinfo["email"],
          first_name: @userinfo["given_name"],
          last_name: @userinfo["usual_name"],
          name: [@userinfo["given_name"], @userinfo["usual_name"]].compact.join(" "),
          phone: @userinfo["phone_number"],
          provider: "proconnect",
          uid: @userinfo["sub"]
        }
      end

      extra do
        { raw_info: @userinfo }
      end

      private

      def connection
        @connection ||= Faraday.new(url: options[:proconnect_domain]) do |c|
          c.request :url_encoded

          c.response :json
          c.response :raise_error
        end
      end

      def discovered_configuration
        @discovered_configuration ||= discover_endpoint!
      end

      def discover_endpoint!
        connection.get(".well-known/openid-configuration").body
      end

      def authorization_uri
        URI(discovered_configuration["authorization_endpoint"]).tap do |endpoint|
          endpoint.query = URI.encode_www_form(
            response_type: "code",
            client_id: options[:client_id],
            redirect_uri: options[:redirect_uri],
            scope: options[:scope],
            state: store_new_state!,
            nonce: store_new_nonce!
          )
        end
      end

      def end_session_uri
        URI(discovered_configuration["end_session_endpoint"]).tap do |endpoint|
          endpoint.query = URI.encode_www_form(
            id_token_hint: session["omniauth.pc.id_token"],
            state: current_state,
            post_logout_redirect_uri: options[:post_logout_redirect_uri]
          )
        end
      end

      def exchange_authorization_code!(code)
        connection.post(URI(discovered_configuration["token_endpoint"]),
                        URI.encode_www_form(
                          grant_type: "authorization_code",
                          client_id: options[:client_id],
                          client_secret: options[:client_secret],
                          redirect_uri: options[:redirect_uri],
                          code: code
                        ))
      end

      def store_tokens!(response)
        response.tap do |res|
          %w[access id refresh].each do |name|
            session["omniauth.pc.#{name}_token"] = res.body["#{name}_token"]
          end
        end
      end

      def get_userinfo!
        endpoint = URI(discovered_configuration["userinfo_endpoint"])
        token = session["omniauth.pc.access_token"]

        connection.get(endpoint, {}, "Authorization" => "Bearer #{token}")
      end

      def engage_logout!
        redirect end_session_uri
      end

      def on_logout_path?
        # FIXME: maybe don't hardcode this
        request.path.end_with?("#{request_path}/logout")
      end

      def store_new_state!
        session["omniauth.state"] = SecureRandom.hex(16)
      end

      def current_state
        session["omniauth.state"]
      end

      def store_new_nonce!
        session["omniauth.nonce"] = SecureRandom.hex(16)
      end

      def verify_state!(other_state)
        # rubocop:disable Style/GuardClause
        if other_state != current_state
          raise "a request came back with a different 'state' parameter than what we had last stored."
        end
        # rubocop:enable Style/GuardClause
      end
    end
  end
end
