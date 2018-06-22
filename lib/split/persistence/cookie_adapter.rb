# frozen_string_literal: true
require "json"

module Split
  module Persistence
    class CookieAdapter
      DEFAULT_CONFIG = {cookie_key_name: "split"}.freeze

      def initialize(context)
        @context = context
        @request, @response = context.request, context.response
        @cookies = @request.cookies
        @expires = Time.now + cookie_length_config
      end

      def [](key)
        hash[key.to_s]
      end

      def []=(key, value)
        set_cookie(hash.merge!(key.to_s => value))
      end

      def delete(key)
        set_cookie(hash.tap { |h| h.delete(key.to_s) })
      end

      def keys
        hash.keys
      end

      private

      def set_cookie(value = {})
        cookie_key = self.class.config[:cookie_key_name].to_s
        cookie_value = default_options.merge(value: JSON.generate(value))
        if action_dispatch?
          @context.cookies[cookie_key] = cookie_value
        else
          set_cookie_via_rack(cookie_key, cookie_value)
        end
      end

      def default_options
        { expires: @expires, path: '/' }
      end

      def set_cookie_via_rack(key, value)
        delete_cookie_header!(@response.header, key, value)
        Rack::Utils.set_cookie_header!(@response.header, key, value)
      end

      # Use Rack::Utils#make_delete_cookie_header after Rack 2.0.0
      def delete_cookie_header!(header, key, value)
        cookie_header = header['Set-Cookie']
        case cookie_header
        when nil, ''
          cookies = []
        when String
          cookies = cookie_header.split("\n")
        when Array
          cookies = cookie_header
        end

        cookies.reject! { |cookie| cookie =~ /\A#{Rack::Utils.escape(key)}=/ }
        header['Set-Cookie'] = cookies.join("\n")
      end

      def hash
        @hash ||= begin
          if cookies = @cookies[self.class.config[:cookie_key_name].to_s]
            begin
              JSON.parse(cookies)
            rescue JSON::ParserError
              {}
            end
          else
            {}
          end
        end
      end

      def cookie_length_config
        Split.configuration.persistence_cookie_length
      end

      def action_dispatch?
        defined?(Rails) && @response.is_a?(ActionDispatch::Response)
      end

      def self.with_config(options={})
        self.config.merge!(options)
        self
      end

      def self.config
        @config ||= DEFAULT_CONFIG.dup
      end

      def self.reset_config!
        @config = DEFAULT_CONFIG.dup
      end
    end
  end
end
