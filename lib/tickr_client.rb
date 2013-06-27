require 'json'
require 'net/http'
require 'thread_safe'
require 'timeout'

class TickrClient
  attr_accessor :servers, :timeout, :cache_size, :replenish_cache_at

  def initialize(opts)
    self.servers = opts[:servers]
    self.timeout = opts[:timeout] || 1000
    self.cache_size = opts[:cache_size] || 100
    self.replenish_cache_at = opts[:replenish_cache_at] || 10

    self.query_in_progress = false
    self.next_server_index = Random.new.rand(servers.count)
    self.tickets = ThreadSafe::Array.new

    fetch_tickets
  end

  def get_ticket
    fetch_tickets if tickets.count == 0
    this_ticket = tickets.shift
    fetch_tickets_async if tickets.count <= replenish_cache_at

    this_ticket
  end

  protected
  attr_accessor :next_server_index, :tickets, :query_in_progress

  def fetch_tickets
    # Try every server up to three times.
    while !fetch_tickets_from_server(next_server_index) do
      self.next_server_index = (self.next_server_index + 1) % servers.count
    end
  end

  def fetch_tickets_from_server(index)
    new_tickets = begin
      uri = URI("http://#{servers[index][:host]}:#{servers[index][:port]}/tickets/create/#{replenish_capacity}")
      Timeout::timeout(timeout / 1000.0) do
        JSON.parse(Net::HTTP.get(uri))
      end
    rescue Timeout::Error
      return false
    end

    tickets.concat(new_tickets)
    true
  end

  def fetch_tickets_async
    return if self.query_in_progress
    self.query_in_progress = true
    Thread.new do
      fetch_tickets
      self.query_in_progress = false
    end
  end

  def replenish_capacity
    cache_size - tickets.count
  end
end
