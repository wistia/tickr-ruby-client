require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

require File.join(File.dirname(__FILE__), '..', 'lib', 'tickr_client')

require 'json'

describe TickrClient do
  def create_client(num_servers = 4, http_password = nil, client_opts = {})
    client_opts[:cache_size] ||= 10
    ports = (8080..(8080 + num_servers - 1))
    ports.each do |port|
      FakeWeb.register_uri :get, "http://#{":#{http_password}@" if http_password}127.0.0.1:#{port}/tickets/create/#{client_opts[:cache_size]}", body: {'first' => 1, 'increment' => 1, 'count' => 5}.to_json
    end
    TickrClient.new(
      client_opts.merge(servers: ports.inject([]) {|servers, port| servers.push({host: '127.0.0.1', port: port, http_auth_password: http_password})})
    )
  end

  after do
    # Make sure threads finish before we fail based on expectations
    Thread.list.each {|t| t.join unless t == Thread.current}
  end
  describe '#initialize' do
    it 'sets configurable instance variables' do
      (8080..8081).each do |port|
        FakeWeb.register_uri :get, "http://127.0.0.1:#{port}/tickets/create/500", body: {'first' => 1, 'increment' => 1, 'count' => 5}.to_json
      end
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
      (8080..8081).each do |port|
        FakeWeb.register_uri :get, "http://127.0.0.1:#{port}/tickets/create/100", body: {'first' => 1, 'increment' => 1, 'count' => 5}.to_json
      end

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
    it 'supports http authentication enabled' do
      # Notice that there is no register_uri set for a non-http authed request.
      # Therefore if a non-http authed request is made, it will bomb.
      FakeWeb.register_uri :get, 'http://:password@127.0.0.1:8080/tickets/create/100', body: {'first' => 1, 'increment' => 1, 'count' => 5}.to_json
      TickrClient.new(
        servers: [{host: '127.0.0.1', port: 8080, http_auth_password: 'password'}]
      )
    end
  end

  describe '#get_ticket' do
    it 'loads ticket from cache and removes it from the cache' do
      client = create_client(1, nil, cache_size: 4, replenish_cache_at: 2)
      client.send(:tickets=, [1, 2, 3, 4])
      client.get_ticket.should == 1
      client.send(:tickets).should == [2, 3, 4]
    end

    it 'asynchronously fetches more tickets after falling below the replenesh_cache_at threshold' do
      client = create_client(2, nil, cache_size: 10, replenesh_cache_at: 2)
      client.send(:tickets=, [5, 6, 7])
      client.should_receive :fetch_tickets_async
      client.get_ticket
    end
  end

  describe 'private instance methods' do
    describe '#fetch_tickets' do
      it 'fetches tickets from servers one at a time until it succeeds' do
        client = create_client(4)
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
        client = create_client(1, nil, cache_size: 10)
        client.send(:tickets=, [1, 2])
        FakeWeb.register_uri :get, 'http://127.0.0.1:8080/tickets/create/8', body: {'first' => 5, 'increment' => 1, 'count' => 8}.to_json

        client.send(:fetch_tickets_async)
        client.send(:tickets).should == [1, 2] # Thread will not have finished yet
        Thread.list.each {|t| t.join unless t == Thread.current}
        client.send(:tickets).should == [1, 2, 5, 6, 7, 8, 9, 10, 11, 12]
      end
    end

    describe '#fetch_tickets_from_server' do
      it 'returns false on timeout error' do
        client = create_client(2)
        Net::HTTP.should_receive(:new).and_raise(Timeout::Error)
        client.send(:fetch_tickets_from_server, 0).should be_false
      end

      it 'adds tickets to array and returns true' do
        client = create_client(3, nil, cache_size: 10)
        client.send(:tickets=, [1, 2])
        client.send(:next_server_index=, 1)

        FakeWeb.register_uri :get, 'http://127.0.0.1:8081/tickets/create/8', body: {'first' => 5, 'increment' => 1, 'count' => 8}.to_json

        client.send(:fetch_tickets_from_server, 1).should be_true
        client.send(:tickets).should == [1, 2, 5, 6, 7, 8, 9, 10, 11, 12]
      end
    end

    describe '#replenish_capacity' do
      it 'is the difference between the cache size and the number of tickets' do
        client = create_client(2, nil, cache_size: 10)
        client.send(:tickets=, [5, 6, 7])
        client.send(:replenish_capacity).should == 7
      end
    end

    describe '#create_tickets_from_ticket_group' do
      it 'should create an array of tickets' do
        client = create_client(2)
        tickets = client.send(:create_tickets_from_ticket_group, {'first' => 100, 'increment' => 100, 'count' => 5})
        tickets.should == [100, 200, 300, 400, 500]
      end
    end
  end
end
