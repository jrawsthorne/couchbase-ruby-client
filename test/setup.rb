require 'minitest/autorun'
require 'mocha'
require 'couchbase'
require 'yajl'

class MiniTest::Unit::TestCase
  # retry block +attempts+ times and fail if time is out
  def assert_operation_completed(attempts = 10)
    timeout = 1
    attempts.times do
      sleep(timeout)
      return if yield
      timeout *= 2
    end
    flunk "Time is out!"
  end

  # fetch list of databases and check if all vbuckets database ready
  def database_ready(bucket)
    all_dbs_uri = bucket.next_node.couch_api_base.sub(bucket.name, '_all_dbs')
    bucket.http_get(all_dbs_uri).grep(/#{bucket.name}\/\d+/).size == bucket.vbuckets.size
  end

  def json_fixture(path, options = {})
    data = File.read(File.join(File.dirname(__FILE__), 'support', path))
    options[:raw] ? data : Yajl::Parser.parse(data)
  end
end
