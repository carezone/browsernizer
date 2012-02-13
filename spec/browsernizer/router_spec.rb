require 'spec_helper'

describe Browsernizer::Router do

  let(:app) { mock() }

  subject do
    Browsernizer::Router.new(app) do |config|
      config.supported "Firefox", "4"
      config.supported "Chrome", "7.1"
    end
  end

  let(:default_env) do
    {
      "HTTP_USER_AGENT" => chrome_agent("7.1.1"),
      "HTTP_ACCEPT" => "text/html",
      "PATH_INFO" => "/index"
    }
  end

  context "All Good" do
    it "sets browsernizer env and propagates request" do
      response = default_env.dup
      response['browsernizer'] = {
        'supported' => true,
        'browser' => "Chrome",
        'version' => "7.1.1"
      }
      app.should_receive(:call).with(response)
      subject.call(default_env)
    end

    it "supports Internet Explorer 6 HTTP_ACCEPT: */* header" do
      default_env.merge!({
        'HTTP_USER_AGENT' => 'Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1; SV1)',
        'HTTP_ACCEPT' => '*/*'
      })

      response = default_env.dup
      response['browsernizer'] = {
        'supported' => true,
        'browser' => "Internet Explorer",
        'version' => "6.0"
      }

      app.should_receive(:call).with(response)
      subject.call(default_env)
    end
  end

  context "Unsupported Browser" do
    before do
      @env = default_env.merge({
        "HTTP_USER_AGENT" => chrome_agent("7")
      })
    end

    it "updates 'browsernizer' env variable and propagates request" do
      @response = @env.dup
      @response['browsernizer'] = {
        'supported' => false,
        'browser' => "Chrome",
        'version' => "7"
      }
      app.should_receive(:call).with(@response)
      subject.call(@env)
    end

    context "location is set" do
      before do
        subject.config.location "/browser.html"
      end
      it "prevents propagation" do
        app.should_not_receive(:call)
        subject.call(@env)
      end
      it "redirects to proper location" do
        response = subject.call(@env)
        response[0].should == 307
        response[1]["Location"].should == "/browser.html"
      end
    end

    context "Non-html request" do
      before do
        @env = @env.merge({
          "HTTP_ACCEPT" => "text/css"
        })
      end
      it "propagates request" do
        app.should_receive(:call).with(@env)
        subject.call(@env)
      end
    end

    context "Already on /browser.html page" do
      before do
        @env = @env.merge({
          "PATH_INFO" => "/browser.html"
        })
      end
      it "propagates request" do
        app.should_receive(:call).with(@env)
        subject.call(@env)
      end
    end

    it "blocks Internet Explorer 6 HTTP_ACCEPT: */* header" do
      default_env.merge!({
        'HTTP_USER_AGENT' => 'Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1; SV1)',
        'HTTP_ACCEPT' => '*/*'
      })

      response = default_env.dup
      response['browsernizer'] = {
        'supported' => false,
        'browser' => "Internet Explorer",
        'version' => "6.0"
      }

      app.should_receive(:call).with(response)

      router = Browsernizer::Router.new(app) do |config|
        config.supported 'Internet Explorer', '7'
      end

      router.call(default_env)
    end
  end


  def chrome_agent(version)
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_7_2) AppleWebKit/535.7 (KHTML, like Gecko) Chrome/#{version} Safari/535.7"
  end

end
