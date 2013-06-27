# tickr_client

tickr_client is a Ruby library for talking to a [tickr ticketing server](http://github.com/wistia/tickr-server).

## Getting Started

It is recommended that you create a global instance of tickr_client and call it directly. TickrClients are threadsafe and the `#get_ticket` method may be called safely on a single instance from all of your request handlers and workers.

Note that the threadsafe guarantee for a ticket is only its uniqueness; tickr makes no guarantee about sequentiality.

    $my_tickr = TickrClient.new(
      servers: [
        {host: '192.168.1.1', port: 8080},
        {host: '192.168.1.2', port: 8080},
        {host: '192.168.1.3', port: 8080}
      ],
      timeout: 1000, # Try next host after 1 second.
      cache_size: 100, # Keep up to 100 tickets (unique IDs) at the ready.
      replenish_cache_at: 10, # Load 90 more tickets when we get down to 10.
    )
    
    new_id = $my_tickr.get_ticket



## Contributing to tickr_client
 
* Check out the issue tracker to make sure someone already hasn't requested it and/or contributed it.
* Fork the project.
* Start a feature/bugfix branch.
* Commit and push until you are happy with your contribution.
* Make sure to add tests for it. This is important so I don't break it in a future version unintentionally.
* Please try not to mess with the Rakefile, version, or history. If you want to have your own version, or is otherwise
necessary, that is fine, but please isolate to its own commit so I can cherry-pick around it.


