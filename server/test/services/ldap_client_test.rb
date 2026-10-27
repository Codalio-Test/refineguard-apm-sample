# frozen_string_literal: true

require "test_helper"

# The minimal LDAPv3 client, exercised against in-process fake directory
# servers: a plaintext bind, a rejected bind, a StartTLS upgrade, LDAPS, a
# refused StartTLS and a silent server.
class LdapClientTest < ActiveSupport::TestCase
  # ---- BER helpers (written independently of the client) -------------------

  module Ber
    module_function

    def tlv(tag, content)
      content = content.b
      [ tag ].pack("C") + length(content.bytesize) + content
    end

    def length(size)
      return [ size ].pack("C") if size < 0x80

      bytes = []
      rest = size
      while rest.positive?
        bytes.unshift(rest & 0xFF)
        rest >>= 8
      end
      [ (0x80 | bytes.length) ].pack("C") + bytes.pack("C*")
    end

    def integer(value)
      tlv(0x02, [ value ].pack("C"))
    end

    def string(value)
      tlv(0x04, value.to_s)
    end

    def message(id, op)
      tlv(0x30, integer(id) + op)
    end

    def bind_response(code)
      message(1, tlv(0x61, integer(code) + string("") + string("")))
    end

    def extended_response(code)
      message(1, tlv(0x78, integer(code) + string("")))
    end
  end

  # A one-shot fake directory.
  class FakeDirectory
    attr_reader :port

    def initialize(bind_code: 0, tls: false, starttls_code: nil, silent: false)
      @bind_code = bind_code
      @tls = tls
      @starttls_code = starttls_code
      @silent = silent
      @listener = TCPServer.new("127.0.0.1", 0)
      @port = @listener.addr[1]
      @thread = Thread.new { serve }
    end

    def close
      @thread&.join(1)
      @listener.close
    rescue IOError
      nil
    end

    private

    def serve
      socket = @listener.accept
      socket = wrap(socket) if @tls

      if @starttls_code
        read(socket)
        socket.write(Ber.extended_response(@starttls_code))
        socket = wrap(socket) if @starttls_code.zero?
      end

      read(socket)
      if @silent
        sleep 2
      else
        socket.write(Ber.bind_response(@bind_code))
      end
      socket.close
    rescue StandardError, IOError
      nil
    end

    def read(socket)
      IO.select([ socket ], nil, nil, 2)
      socket.read_nonblock(4096)
    end

    def wrap(socket)
      context = OpenSSL::SSL::SSLContext.new
      context.cert, context.key = LdapClientTest.certificate
      ssl = OpenSSL::SSL::SSLSocket.new(socket, context)
      ssl.sync_close = true
      ssl.accept
      ssl
    end
  end

  class << self
    # A self-signed certificate for 127.0.0.1, plus the PEM path the client's
    # default trust store is pointed at through SSL_CERT_FILE.
    def certificate
      @certificate ||= build_certificate
    end

    def certificate_path
      @certificate_path ||= begin
        path = Rails.root.join("tmp/ldap-test-cert.pem")
        File.write(path, certificate[0].to_pem)
        path.to_s
      end
    end

    private

    def build_certificate
      key = OpenSSL::PKey::RSA.new(2048)
      cert = OpenSSL::X509::Certificate.new
      cert.version = 2
      cert.serial = 1
      name = OpenSSL::X509::Name.parse("/CN=127.0.0.1")
      cert.subject = name
      cert.issuer = name
      cert.public_key = key.public_key
      cert.not_before = Time.now - 3600
      cert.not_after = Time.now + 86_400
      factory = OpenSSL::X509::ExtensionFactory.new
      factory.subject_certificate = cert
      factory.issuer_certificate = cert
      cert.add_extension(factory.create_extension("basicConstraints", "CA:TRUE", true))
      cert.add_extension(factory.create_extension("keyUsage", "digitalSignature,keyEncipherment", true))
      cert.add_extension(factory.create_extension("subjectAltName", "IP:127.0.0.1,DNS:localhost"))
      cert.sign(key, OpenSSL::Digest.new("SHA256"))
      [ cert, key ]
    end
  end

  setup do
    @original_cert_file = ENV["SSL_CERT_FILE"]
    @original_ca_file = ENV["REFINEGUARD_LDAP_CA_FILE"]
    ENV["REFINEGUARD_LDAP_CA_FILE"] = self.class.certificate_path
  end

  teardown do
    ENV["SSL_CERT_FILE"] = @original_cert_file
    ENV["REFINEGUARD_LDAP_CA_FILE"] = @original_ca_file
  end

  def client(port, tls: :none)
    Refineguard::Ldap::Client.new(host: "127.0.0.1", port: port, timeout: 2.0, tls: tls)
  end

  test "a plaintext simple bind reports success" do
    server = FakeDirectory.new(bind_code: 0)
    result = client(server.port).simple_bind(dn: "cn=a@b.local", password: "secret")

    assert result.success
    assert_equal "Authenticated", result.message
  ensure
    server&.close
  end

  test "a rejected bind reports the LDAP result code" do
    server = FakeDirectory.new(bind_code: 49)
    result = client(server.port).simple_bind(dn: "cn=a@b.local", password: "secret")

    assert_not result.success
    assert_match(/LDAP result 49/, result.message)
  ensure
    server&.close
  end

  test "a directory that does not answer times out" do
    server = FakeDirectory.new(silent: true)

    assert_raises(Timeout::Error) do
      Refineguard::Ldap::Client.new(host: "127.0.0.1", port: server.port, timeout: 0.2)
                              .simple_bind(dn: "cn=a", password: "x")
    end
  ensure
    server&.close
  end

  test "a refused StartTLS upgrade raises" do
    server = FakeDirectory.new(starttls_code: 2)

    assert_raises(Refineguard::Ldap::Client::StartTlsRefused) do
      client(server.port, tls: :start_tls).simple_bind(dn: "cn=a", password: "x")
    end
  ensure
    server&.close
  end

  test "StartTLS upgrades the connection and binds over TLS" do
    server = FakeDirectory.new(starttls_code: 0, bind_code: 0)
    result = client(server.port, tls: :start_tls).simple_bind(dn: "cn=a", password: "x")

    assert result.success
  ensure
    server&.close
  end

  test "LDAPS negotiates TLS from the first byte" do
    server = FakeDirectory.new(tls: true, bind_code: 0)
    result = client(server.port, tls: :ldaps).simple_bind(dn: "cn=a", password: "x")

    assert result.success
  ensure
    server&.close
  end

  test "the client exposes the transport it was built for" do
    assert_equal :none, client(1).tls
    assert_equal "127.0.0.1", client(1).host
    assert_equal 1, client(1).port
  end
end
