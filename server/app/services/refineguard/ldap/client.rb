# frozen_string_literal: true

require "openssl"
require "socket"

module Refineguard
  module Ldap
    # A minimal LDAPv3 client that performs a real simple bind over TLS.
    #
    # Ruby ships no LDAP library, and the OT directory is a local appliance, so
    # this speaks just enough of the protocol (a BER-encoded BindRequest and its
    # BindResponse) to verify a credential against a real directory. The
    # transport is selected by `tls:`:
    #   :ldaps     — TLS from the first byte (usually port 636)
    #   :start_tls — a plaintext connection upgraded with the StartTLS extended op
    #   :none      — plaintext (only reachable when the adapter explicitly allows it)
    # A plaintext path is therefore never the default.
    class Client
      SEQUENCE = 0x30
      INTEGER = 0x02
      OCTET_STRING = 0x04
      BIND_REQUEST = 0x60
      BIND_RESPONSE = 0x61
      SIMPLE_AUTH = 0x80
      EXTENDED_REQUEST = 0x77
      EXTENDED_RESPONSE = 0x78
      REQUEST_NAME = 0x80
      LDAP_VERSION = 3
      RESULT_SUCCESS = 0
      START_TLS_OID = "1.3.6.1.4.1.1466.20037"

      Result = Struct.new(:success, :message, keyword_init: true)

      # Raised when the directory refuses to upgrade the connection to TLS.
      class StartTlsRefused < StandardError; end

      # The transport the client was built for (:ldaps, :start_tls or :none).
      attr_reader :host, :port, :tls

      def initialize(host:, port:, timeout: 3.0, tls: :none)
        @host = host
        @port = port
        @timeout = timeout
        @tls = tls
      end

      # @return [Result]
      def simple_bind(dn:, password:)
        socket = connect
        begin
          response = exchange(socket, encode_message(1, encode_bind_request(dn, password)))
          code = result_code(response)
          return Result.new(success: true, message: "Authenticated") if code == RESULT_SUCCESS

          Result.new(success: false, message: "Directory rejected the bind (LDAP result #{code})")
        ensure
          socket.close
        end
      end

      private

      # Opens the transport, applying TLS up front for LDAPS or upgrading an
      # existing plaintext connection for StartTLS.
      def connect
        socket = Socket.tcp(@host, @port, connect_timeout: @timeout)
        return wrap_in_tls(socket) if @tls == :ldaps
        return upgrade_with_start_tls(socket) if @tls == :start_tls

        socket
      end

      def upgrade_with_start_tls(socket)
        socket.write(encode_message(1, encode_extended_request(START_TLS_OID)))
        response = read_response(socket)
        code = result_code(response, expected_tag: EXTENDED_RESPONSE)
        raise StartTlsRefused, "directory refused StartTLS (LDAP result #{code})" unless code == RESULT_SUCCESS

        wrap_in_tls(socket)
      rescue StandardError
        socket.close
        raise
      end

      def wrap_in_tls(socket)
        context = OpenSSL::SSL::SSLContext.new
        # A private OT certificate authority can be trusted explicitly; without
        # it the system default trust store is used.
        ca_file = Refineguard::Ldap.configuration.ca_file
        context.ca_file = ca_file if ca_file.present?
        context.set_params
        ssl = OpenSSL::SSL::SSLSocket.new(socket, context)
        ssl.hostname = @host
        ssl.sync_close = true
        ssl.connect
        ssl
      end

      def exchange(socket, message)
        socket.write(message)
        read_response(socket)
      end

      def read_response(socket)
        ready = IO.select([ socket ], nil, nil, @timeout)
        raise Timeout::Error, "directory did not answer the bind" unless ready

        read_available(socket)
      end

      # A TLS socket may need another read pass even after the selector reported
      # it readable, because the TLS record layer buffers.
      def read_available(socket)
        loop do
          begin
            return socket.read_nonblock(4096)
          rescue IO::WaitReadable
            unless IO.select([ socket ], nil, nil, @timeout)
              raise Timeout::Error, "directory did not answer the bind"
            end
          end
        end
      end

      def result_code(bytes, expected_tag: BIND_RESPONSE)
        _tag, message, = read_tlv(bytes, 0)
        offset = skip_tlv(message, 0)                 # messageID
        response_tag, response, = read_tlv(message, offset)
        raise "unexpected LDAP response tag #{response_tag}" unless response_tag == expected_tag

        code_tag, code, = read_tlv(response, 0)
        raise "malformed LDAP response" unless code_tag == INTEGER

        code.bytes.reduce(0) { |acc, byte| (acc << 8) | byte }
      end

      def read_tlv(bytes, offset)
        tag = bytes.getbyte(offset)
        length, length_bytes = decode_length(bytes, offset + 1)
        header = 1 + length_bytes
        content = bytes.byteslice(offset + header, length)
        [ tag, content, offset + header + length ]
      end

      def skip_tlv(bytes, offset)
        _tag, _content, next_offset = read_tlv(bytes, offset)
        next_offset
      end

      def decode_length(bytes, offset)
        first = bytes.getbyte(offset)
        return [ first, 1 ] if first < 0x80

        count = first & 0x7F
        length = 0
        count.times { |index| length = (length << 8) | bytes.getbyte(offset + 1 + index) }
        [ length, 1 + count ]
      end

      def encode_message(message_id, protocol_op)
        tlv(SEQUENCE, integer(message_id) + protocol_op)
      end

      def encode_bind_request(dn, password)
        tlv(BIND_REQUEST, integer(LDAP_VERSION) + octet_string(dn) + tlv(SIMPLE_AUTH, password.to_s))
      end

      def encode_extended_request(oid)
        tlv(EXTENDED_REQUEST, tlv(REQUEST_NAME, oid))
      end

      def integer(value)
        bytes = [ value ]
        rest = value >> 8
        while rest.positive?
          bytes.unshift(rest & 0xFF)
          rest >>= 8
        end
        bytes.unshift(0) if (bytes.first & 0x80) == 0x80
        tlv(INTEGER, bytes.pack("C*"))
      end

      def octet_string(value)
        tlv(OCTET_STRING, value.to_s)
      end

      def tlv(tag, content)
        content = content.b
        [ tag ].pack("C") + length_bytes(content.bytesize) + content
      end

      def length_bytes(length)
        return [ length ].pack("C") if length < 0x80

        bytes = []
        rest = length
        while rest.positive?
          bytes.unshift(rest & 0xFF)
          rest >>= 8
        end
        [ (0x80 | bytes.length) ].pack("C") + bytes.pack("C*")
      end
    end
  end
end
