# -*- coding: binary -*-

require 'spec_helper'

RSpec.describe Msf::Exploit::Remote::X11::Extensions do
  subject do
    mod = ::Msf::Exploit.new
    mod.extend described_class

    mod.send(:initialize)
    mod
  end

  let(:query_extension) do
    "\x62\x00\x05\x00\f\x00\x00\x00BIG-REQUESTS"
  end

  let(:query_extension2) do
    "\x62\x00\x05\x00\t\x00\x00\x00XKEYBOARD\x00\x00\x00"
  end

  let(:query_extension_resp) do
    "\x01\x00\x01\x00\x00\x00\x00\x00\x01\x86\x00\x00\x00\x00\x00\x00" \
    "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
  end

  let(:enable_134) do
    "\x86\x00\x01\x00"
  end

  describe 'creates QueryExtension request for full length plugin' do
    it do
      request = Msf::Exploit::Remote::X11::Extensions::X11QueryExtensionRequest.read(query_extension)
      expect(request.extension).to eq('BIG-REQUESTS')
      request = Msf::Exploit::Remote::X11::Extensions::X11QueryExtensionRequest.new(extension: 'BIG-REQUESTS')
      expect(request.to_binary_s).to eq(query_extension)
    end
  end

  describe 'creates QueryExtension request for short length plugin' do
    it do
      request = Msf::Exploit::Remote::X11::Extensions::X11QueryExtensionRequest.read(query_extension2)
      expect(request.extension).to eq('XKEYBOARD')
      request = Msf::Exploit::Remote::X11::Extensions::X11QueryExtensionRequest.new(extension: 'XKEYBOARD')
      expect(request.to_binary_s).to eq(query_extension2)
    end
  end

  describe 'handles QueryExtension response' do
    it do
      response = Msf::Exploit::Remote::X11::Extensions::X11QueryExtensionResponse.read(query_extension_resp)
      expect(response.major_opcode).to eq(134)
      expect(response.present).to eq(1)
    end
  end

  describe 'creates Extension Toggle request' do
    it do
      request = Msf::Exploit::Remote::X11::Extensions::X11ExtensionToggleRequest.read(enable_134)
      expect(request.opcode).to eq(134)
      expect(request.wanted_major).to eq(0)
      expect(request.wanted_major).to eq(0)
      expect(request.request_length).to eq(1)
      request = Msf::Exploit::Remote::X11::Extensions::X11ExtensionToggleRequest.new(opcode: 134)
      expect(request.to_binary_s).to eq(enable_134)
    end
  end
end
