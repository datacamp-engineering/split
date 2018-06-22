# frozen_string_literal: true
require "spec_helper"
require 'rack/test'

describe Split::Persistence::CookieAdapter do

  let(:env) { Rack::MockRequest.env_for("http://example.com:8080/") }
  let(:request) { Rack::Request.new(env) }
  let(:response) { Rack::MockResponse.new(200, {}, "") }
  let(:context) { double(request: request, response: response, cookies: CookiesMock.new) }
  subject { Split::Persistence::CookieAdapter.new(context) }

  describe "#[] and #[]=" do
    it "should set and return the value for given key" do
      subject["my_key"] = "my_value"
      expect(subject["my_key"]).to eq("my_value")
    end
  end

  describe ".config" do
    context 'config with overridden cookie key name' do
      before { Split::Persistence::CookieAdapter.with_config(:cookie_key_name => 'foo123') }

      it 'should be "foo123"' do
        expect(Split::Persistence::CookieAdapter.config[:cookie_key_name]).to eq('foo123')
      end
    end
  end

  describe "#delete" do
    it "should delete the given key" do
      subject["my_key"] = "my_value"
      subject.delete("my_key")
      expect(subject["my_key"]).to be_nil
    end
  end

  describe "#keys" do
    it "should return an array of the session's stored keys" do
      subject["my_key"] = "my_value"
      subject["my_second_key"] = "my_second_value"
      expect(subject.keys).to match(["my_key", "my_second_key"])
    end
  end

  it "handles invalid JSON" do
    context.request.cookies[:split] = { :value => '{"foo":2,', :expires => Time.now }
    expect(subject["my_key"]).to be_nil
    subject["my_key"] = "my_value"
    expect(subject["my_key"]).to eq("my_value")
  end

  it "puts multiple experiments in a single cookie" do
    subject["foo"] = "FOO"
    subject["bar"] = "BAR"
    expect(context.response.headers["Set-Cookie"]).to match(/\Asplit=%7B%22foo%22%3A%22FOO%22%2C%22bar%22%3A%22BAR%22%7D; path=\/; expires=[a-zA-Z]{3}, \d{2} [a-zA-Z]{3} \d{4} \d{2}:\d{2}:\d{2} -0000\Z/)
  end

  it "ensure other added cookies are not overriden" do
    context.response.set_cookie 'dummy', 'wow'
    subject["foo"] = "FOO"
    expect(context.response.headers["Set-Cookie"]).to include("dummy=wow")
    expect(context.response.headers["Set-Cookie"]).to include("split=")
  end

  it "uses ActionDispatch::Cookie when available for cookie writing" do
    allow(subject).to receive(:action_dispatch?).and_return(true)
    subject["foo"] = "FOO"
    expect(subject['foo']).to eq('FOO')
  end

end
