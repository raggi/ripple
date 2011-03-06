# Copyright 2010 Sean Cribbs, Sonian Inc., and Basho Technologies, Inc.
#
#    Licensed under the Apache License, Version 2.0 (the "License");
#    you may not use this file except in compliance with the License.
#    You may obtain a copy of the License at
#
#        http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.
require 'riak'

module Riak
  class Client
    # Uses the Ruby standard library Net::HTTP to connect to Riak.
    # We recommend using the CurbBackend, which will
    # be preferred when the 'curb' library is available.
    # Conforms to the Riak::Client::HTTPBackend interface.
    class NetHTTPBackend < HTTPBackend
      def self.configured?
        begin
          require 'net/http/persistent'
          true
        rescue LoadError, NameError
          false
        end
      end

      private
      def http
        @http ||= Net::HTTP::Persistent.new
      end

      def perform(method, uri, headers, expect, data=nil) #:nodoc:
        request = Net::HTTP.const_get(method.to_s.capitalize).new(uri.request_uri, headers)
        case data
        when String
          request.body = data
        when IO
          request.body_stream = data
        end

        result = {}
        http.request(uri, request) do |response|
          unless valid_response?(expect, response.code)
            raise FailedRequest.new(method, expect, response.code.to_i, response.to_hash, response.body)
          end
          
          result.merge!( :headers => response.to_hash, :code => response.code.to_i )
          response.read_body {|chunk| yield chunk } if block_given?
          if return_body?(method, response.code, block_given?)
            result[:body] = response.body
          end
        end
        result
      end

    end
  end
end
