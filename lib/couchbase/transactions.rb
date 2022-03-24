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

module Couchbase
  # Provides access to transaction APIs
  class Transactions
    def run
      transaction = TransactionAttemptContext.new(@transactions)
      loop do
        transaction.new_attempt

        begin
          yield transaction
        rescue StandardError => e
          puts "block failed, rollback..."
          transaction.rollback
          raise e
        end

        begin
          result = transaction.commit
          unless result
            puts "no result, retry..."
            next
          end

          return result
        rescue StandardError => e
          puts "commit failed, retry..."
        end
      end
    end

    private

    # @param [Couchbase::Backend] backend
    def initialize(backend)
      @transactions = TransactionsBackend.new(backend)
    end
  end

  class TransactionAttemptContext
    def commit
      result = @transaction.commit
      TransactionResult.new do |res|
        res.unstaging_complete = result[:unstaging_complete]
        res.transaction_id = result[:transaction_id]
      end
    end

    def rollback
      @transaction.rollback
    end

    def get; end

    def insert; end

    def replace; end

    def remove; end

    def query; end

    def new_attempt
      @transaction.new_attempt
    end

    private

    def initialize(transactions)
      @transaction = TransactionContextBackend.new(transactions)
    end
  end

  class TransactionResult
    attr_accessor :transaction_id
    attr_accessor :unstaging_complete

    def initialize
      yield self if block_given?
    end
  end
end
