require_relative 'spec_helper'
require 'benchmark'

NUMBER_OF_RUNS = 5000

describe Arango::Server do
  context "benchmark http" do
    before :all do
      @server = connect
      begin
        @server.drop_database("BenchmarkDatabase")
      rescue
      end
      @database = @server.create_database("BenchmarkDatabase")
      @collection = @database.create_collection "MyCollection"
    end

    after :all do
      begin
        @database.drop_collection('MyCollection')
      rescue
      end
      @server.drop_database("BenchmarkDatabase")
    end

    it "version works" do
      expect(@server.version).to be_a String
      puts
    end

    it "doc benchmark in kops" do
      result = nil
      elapsed = Benchmark.realtime do
        # n sets, n get
        NUMBER_OF_RUNS.times do |i|
          key = "foo#{i}"
          @collection.create_document({key: key, value: key * 10})
          result = @collection.get_document(key).value
        end
      end
      NUMBER_OF_RUNS.times do |i|
        key = "foo#{i}"
        @collection.drop_document(key)
      end
      puts 'Write/Read: %.2f Kops' % (2 * NUMBER_OF_RUNS / 1000 / elapsed)
      expect(result).to be_a String
    end

    it "doc benchmark in kops batched" do
      result = nil
      elapsed = Benchmark.realtime do
        # n sets, n get
        NUMBER_OF_RUNS.times do |i|
          key = "foo#{i}"
          @collection.batch_create_document({key: key, value: key * 10}, wait_for_sync: false)
          @collection.batch_get_document(key).then { |doc| result = doc.value }
          @collection.database.execute_batched_requests
        end
      end
      NUMBER_OF_RUNS.times do |i|
        key = "foo#{i}"
        @collection.drop_document(key)
      end
      puts 'Write/Read batched: %.2f Kops' % (2 * NUMBER_OF_RUNS / 1000 / elapsed)
      expect(result).to be_a String
    end

    it "doc write benchmark in kops" do
      elapsed = Benchmark.realtime do
        # n sets, n get
        NUMBER_OF_RUNS.times do |i|
          key = "foo#{i}"
          @collection.create_document({key: key, value: key * 10})
        end
      end
      NUMBER_OF_RUNS.times do |i|
        key = "foo#{i}"
        @collection.drop_document(key)
      end
      puts 'Write: %.2f Kops' % (NUMBER_OF_RUNS / 1000 / elapsed)
    end

    it "doc read benchmark in kops" do
      result = nil
      NUMBER_OF_RUNS.times do |i|
        key = "foo#{i}"
        @collection.create_document({key: key, value: key * 10})
      end
      elapsed = Benchmark.realtime do
        # n sets, n get
        NUMBER_OF_RUNS.times do |i|
          key = "foo#{i}"
          result = @collection.get_document(key).value
        end
      end
      NUMBER_OF_RUNS.times do |i|
        key = "foo#{i}"
        @collection.drop_document(key)
      end
      puts 'Read: %.2f Kops' % (NUMBER_OF_RUNS / 1000 / elapsed)
      expect(result).to be_a String
    end

    it "version benchmark in kops" do
      result = nil
      elapsed = Benchmark.realtime do
        # n sets, n get
        NUMBER_OF_RUNS.times do |i|
          result = @server.version
        end
      end
      puts 'version: %.2f Kops' % (NUMBER_OF_RUNS / 1000 / elapsed)
      expect(result).to be_a String
    end
  end
end
