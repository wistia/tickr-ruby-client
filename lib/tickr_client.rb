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
    new_ticket_group = begin
      uri = URI("http://#{servers[index][:host]}:#{servers[index][:port]}/tickets/create/#{replenish_capacity}")
      Timeout::timeout(timeout / 1000.0) do
        JSON.parse(Net::HTTP.get(uri))
      end
    rescue Timeout::Error
      return false
    end

    new_tickets = create_tickets_from_ticket_group(new_ticket_group)
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

  # Create an array of tickets based on a 'ticket group' array of size 3:
  # 1. First element of ticket group is the first ticket.
  # 2. Second element of ticket group is the increment between consecutive tickets.
  # 3. Third element of ticket group is the number of tickets to create.
  def create_tickets_from_ticket_group(group)
    initial_ticket, diff, num_of_tickets = group['first'], group['increment'], group['count']
    new_tickets = [initial_ticket]

    (num_of_tickets - 1).times do
      new_tickets << new_tickets.last + diff
    end

    new_tickets
  end
end
