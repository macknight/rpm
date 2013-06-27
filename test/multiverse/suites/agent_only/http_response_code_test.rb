# encoding: utf-8
# This file is distributed under New Relic's license terms.
# See https://github.com/newrelic/rpm/blob/master/LICENSE for complete details.

# https://newrelic.atlassian.net/browse/RUBY-765
require 'fake_collector'
require 'multiverse_helpers'

class HttpResponseCodeTest < Test::Unit::TestCase
  include MultiverseHelpers

  def setup
    setup_collector
    NewRelic::Agent.manual_start(:send_data_on_exit => false)
    @agent = NewRelic::Agent.instance
  end

  def teardown
    reset_collector
    NewRelic::Agent.shutdown
  end

  def test_request_entity_too_large
    $collector.mock['metric_data'] = [413, {'exception' => {'error_type' => 'RuntimeError', 'message' => 'too much'}}]

    @agent.stats_engine.get_stats_no_scope('Custom/too_big') \
      .record_data_point(1)
    assert_equal 1, @agent.stats_engine \
      .get_stats_no_scope('Custom/too_big').call_count

    @agent.send(:harvest_and_send_timeslice_data)

    # make sure the data gets thrown away without crashing
    assert_equal 0, @agent.stats_engine \
      .get_stats_no_scope('Custom/too_big').call_count

    # make sure we actually talked to the collector
    assert_equal(1, $collector.agent_data.select{|x| x.action == 'metric_data'}.size)
  end

  def test_unsupported_media_type
    $collector.mock['metric_data'] = [415, {'exception' => {'error_type' => 'RuntimeError', 'message' => 'looks bad'}}]

    @agent.stats_engine.get_stats_no_scope('Custom/too_big') \
      .record_data_point(1)
    assert_equal 1, @agent.stats_engine \
      .get_stats_no_scope('Custom/too_big').call_count

    @agent.send(:harvest_and_send_timeslice_data)

    # make sure the data gets thrown away without crashing
    assert_equal 0, @agent.stats_engine \
      .get_stats_no_scope('Custom/too_big').call_count

    # make sure we actually talked to the collector
    assert_equal(1, $collector.agent_data.select{|x| x.action == 'metric_data'}.size)
  end
end
