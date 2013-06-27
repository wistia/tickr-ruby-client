require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

require File.join(File.dirname(__FILE__), '..', 'lib', 'tickr_client')

require 'json'

describe TickrClient do
  after do
    # Make sure threads finish before we fail based on expectations
    Thread.list.each {|t| t.join unless t == Thread.current}
  end
  def get_client(opts = {})
    TickrClient.new(
      {servers: [{host: '127.0.0.1', port: 8080}, {host: '127.0.0.1', port: 8081}]}.merge(opts)
    )
  end
  describe '#initialize' do
    it 'sets configurable instance variables' do
      TickrClient.any_instance.stub :fetch_tickets
      client = TickrClient.new(
        servers: [{host: '127.0.0.1', port: 8080}, {host: '127.0.0.1', port: 8081}],
        timeout: 150,
        cache_size: 500,
        replenish_cache_at: 100
      )

      client.servers.count.should == 2
      client.timeout.should == 150
      client.cache_size.should == 500
      client.replenish_cache_at.should == 100
    end
    it 'applies sensible defaults' do
      TickrClient.any_instance.stub :fetch_tickets
      client = TickrClient.new(
        servers: [{host: '127.0.0.1', port: 8080}, {host: '127.0.0.1', port: 8081}]
      )
      client.timeout.should_not be_nil
      client.cache_size.should_not be_nil
      client.replenish_cache_at.should_not be_nil
    end
    it 'fetches tickets synchronously' do
      TickrClient.any_instance.should_receive(:fetch_tickets).at_least(1)
      TickrClient.new(
        servers: [{host: '127.0.0.1', port: 8080}, {host: '127.0.0.1', port: 8081}]
      )
    end
  end

  describe '#get_ticket' do
    it 'loads ticket from cache and removes it from the cache' do
      TickrClient.any_instance.stub :fetch_tickets
      client = get_client

      client.send(:tickets=, [1, 2, 3, 4])
      client.get_ticket.should == 1
      client.send(:tickets).should == [2, 3, 4]
    end

    it 'asynchronously fetches more tickets after falling below the replenesh_cache_at threshold' do
      TickrClient.any_instance.stub :fetch_tickets

      client = get_client(cache_size: 10, replenesh_cache_at: 2)
      client.send(:tickets=, [5, 6, 7])
      client.should_receive :fetch_tickets_async
      client.get_ticket
    end
  end

  describe 'private instance methods' do
    describe '#fetch_tickets' do
      it 'fetches tickets from servers one at a time' do
        Net::HTTP.should_receive(:get).and_return([1, 2, 3, 4, 5].to_json)
        client = TickrClient.new(
          servers: [
            {host: '127.0.0.1', port: 8080},
            {host: '127.0.0.1', port: 8081},
            {host: '127.0.0.1', port: 8082},
            {host: '127.0.0.1', port: 8083}
          ]
        )
        Thread.list.each {|t| t.join unless t == Thread.current}

        client.send(:next_server_index=, 0)
        client.should_receive(:fetch_tickets_from_server).with(0).and_return(false)
        client.should_receive(:fetch_tickets_from_server).with(1).and_return(false)
        client.should_receive(:fetch_tickets_from_server).with(2).and_return(false)
        client.should_receive(:fetch_tickets_from_server).with(3).and_return(true)
        client.send(:fetch_tickets)
      end
    end

    describe '#fetch_tickets_async' do
      it 'fetches tickets in a separate thread' do
        FakeWeb.register_uri :get, 'http://127.0.0.1:8080/tickets/create/10', body: [1, 2].to_json
        client = TickrClient.new(
          servers: [
            {host: '127.0.0.1', port: 8080}
          ],
          cache_size: 10
        )
        client.send(:tickets=, [1, 2])
        FakeWeb.register_uri :get, 'http://127.0.0.1:8080/tickets/create/8', body: [5, 6, 7, 8, 9, 10, 11, 12].to_json

        client.send(:fetch_tickets_async)
        client.send(:tickets).should == [1, 2] # Thread will not have finished yet
        Thread.list.each {|t| t.join unless t == Thread.current}
        client.send(:tickets).should == [1, 2, 5, 6, 7, 8, 9, 10, 11, 12]
      end
    end

    describe '#fetch_tickets_from_server' do
      it 'returns false on timeout error' do
        TickrClient.any_instance.stub :fetch_tickets
        client = get_client

        Net::HTTP.should_receive(:get).and_raise(Timeout::Error)
        client.send(:fetch_tickets_from_server, 0).should be_false
      end

      it 'adds tickets to array and returns true' do
        TickrClient.any_instance.stub :fetch_tickets
        client = TickrClient.new(
          servers: [
            {host: '127.0.0.1', port: 8080},
            {host: '127.0.0.1', port: 8081},
            {host: '127.0.0.1', port: 8082}
          ],
          cache_size: 10
        )
        client.send(:tickets=, [1, 2])
        client.send(:next_server_index=, 1)

        FakeWeb.register_uri :get, 'http://127.0.0.1:8081/tickets/create/8', body: [5, 6, 7, 8, 9, 10, 11, 12].to_json

        client.send(:fetch_tickets_from_server, 1).should be_true
        client.send(:tickets).should == [1, 2, 5, 6, 7, 8, 9, 10, 11, 12]
      end
    end

    describe '#replenish_capacity' do
      it 'is the difference between the cache size and the number of tickets' do
        TickrClient.any_instance.stub :fetch_tickets

        client = get_client(cache_size: 10)
        client.send(:tickets=, [5, 6, 7])
        client.send(:replenish_capacity).should == 7
      end
    end
  end
end
