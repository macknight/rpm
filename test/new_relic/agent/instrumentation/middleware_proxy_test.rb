# encoding: utf-8
# This file is distributed under New Relic's license terms.
# See https://github.com/newrelic/rpm/blob/master/LICENSE for complete details.

require File.expand_path(File.join(File.dirname(__FILE__),'..','..','..','test_helper'))

class NewRelic::Agent::Instrumentation::MiddlewareProxyTest < Minitest::Test

  def setup
    NewRelic::Agent.drop_buffered_data
  end

  def test_does_not_wrap_sinatra_apps
    sinatra_dummy_module = Module.new
    sinatra_dummy_class  = Class.new(Object)
    app_class            = Class.new(sinatra_dummy_class)

    with_constant_defined(:'::Sinatra', sinatra_dummy_module) do
      with_constant_defined(:'::Sinatra::Base', sinatra_dummy_class) do
        app = app_class.new

        wrapped = NewRelic::Agent::Instrumentation::MiddlewareProxy.wrap(app)

        assert_same(app, wrapped)
      end
    end
  end

  def test_does_not_wrap_instrumented_middlewares
    app_class = Class.new do
      def _nr_has_middleware_tracing
        true
      end
    end

    app = app_class.new

    wrapped = NewRelic::Agent::Instrumentation::MiddlewareProxy.wrap(app)

    assert_same(app, wrapped)
  end

  def test_should_wrap_non_instrumented_middlewares
    app_class = Class.new do
      def call(env)
        :yay
      end
    end

    app = app_class.new

    wrapped = NewRelic::Agent::Instrumentation::MiddlewareProxy.wrap(app)

    assert_kind_of(NewRelic::Agent::Instrumentation::MiddlewareProxy, wrapped)
  end

  def test_call_should_proxy_to_target_when_in_transaction
    call_was_called = false
    call_received   = nil

    app = lambda do |env|
      call_was_called = true
      call_received   = env
      :super_duper
    end

    wrapped = NewRelic::Agent::Instrumentation::MiddlewareProxy.wrap(app)
    env = {}

    ret = nil
    in_transaction do
      ret = wrapped.call(env)
    end

    assert(call_was_called)
    assert_equal(:super_duper, ret)
    assert_same(env, call_received)
  end

  def test_call_should_proxy_to_target_when_not_in_transaction
    call_was_called = false
    call_received   = nil

    app = lambda do |env|
      call_was_called = true
      call_received   = env
      :super_duper
    end

    wrapped = NewRelic::Agent::Instrumentation::MiddlewareProxy.wrap(app)
    env = {}
    ret = wrapped.call(env)

    assert(call_was_called)
    assert_equal(:super_duper, ret)
    assert_same(env, call_received)
  end

  def test_should_not_start_transaction_if_one_is_running
    app = lambda do |env|
      :super_duper
    end

    wrapped = NewRelic::Agent::Instrumentation::MiddlewareProxy.wrap(app)

    in_transaction do
      NewRelic::Agent::Transaction.expects(:start).never
      wrapped.call({})
    end
  end

  def test_should_start_transaction_if_none_is_running
    app = lambda do |env|
      :super_duper
    end

    wrapped = NewRelic::Agent::Instrumentation::MiddlewareProxy.wrap(app)

    wrapped.call({})

    assert_metrics_recorded("HttpDispatcher")
  end

  def test_should_respect_force_transaction_flag
    app = lambda do |env|
      :super_duper
    end

    wrapped = NewRelic::Agent::Instrumentation::MiddlewareProxy.wrap(app, true)

    in_transaction('Controller/foo', :category => :controller) do
      wrapped.call({})
    end

    assert_metrics_recorded('Controller/Rack/Proc/call')
  end
end
