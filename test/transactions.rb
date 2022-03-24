#  Copyright 2020-2021 Couchbase, Inc.
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.

require_relative "test_helper"

module Couchbase
  class TransactionsTest < Minitest::Test
    include TestUtilities

    def setup
      connect
      skip("#{name}: CAVES does not support query service yet") if use_caves?
    end

    def test_transactions_object
      transactions = @cluster.transactions
      result = transactions.run { puts "hello" }
      puts result.transaction_id
      transactions.run { throw "hello" }
    end
  end
end
