# tickr_client

tickr_client is a Ruby library for talking to a [tickr ticketing server](http://github.com/wistia/tickr-server).

## Getting Started

It is recommended that you create a global instance of tickr_client and call it
directly. TickrClients are threadsafe and the `#get_ticket` method may be
called safely on a single instance from all of your request handlers and
workers.

Note that the threadsafe guarantee for a ticket is only its uniqueness; tickr
makes no guarantee about sequentiality.

    $tickr = TickrClient.new(
      servers: [
        {host: '192.168.1.1', port: 8080, http_auth_password: 'lockd0wn'},
        {host: '192.168.1.2', port: 8080, http_auth_password: 'lockd0wn'},
        {host: '192.168.1.3', port: 8080, http_auth_password: 'lockd0wn'}
      ],
      timeout: 1000, # Try next host after 1 second.
      cache_size: 100, # Keep up to 100 tickets (unique IDs) at the ready.
      replenish_cache_at: 10, # Load 90 more tickets when we get down to 10.
    )
    
    new_id = $tickr.get_ticket

## Using with ActiveRecord

To use tickr with ActiveRecord, set up an initializer as outlined above. The
ActiveRecord interface requires your tickr instance to be a global variable
named `$tickr`. This is not presently configurable (though we'd love for you
to make it so!).

All you need to do to add ActiveRecord support to your ActiveRecord models is
require our interface library and include our mixin, e.g.:

    require 'tickr/interfaces/active_record' # not required with gem by default
    
    class Person < ActiveRecord::Base
      include Tickr::Interfaces::ActiveRecord
      
      # …your code here
    end

Voila! Whenever you save a new object, its ID will be set via tickr and passed
to your DBMS during its insert operation. If for any reason the ID is not set
upon row insertion, Tickr will raise a `TickrIdNotSetError` exception so that
no data is saved that might compromise referential integrity. If you wish to
fall back to an auto_increment or some other DBMS-backed scheme, you should
catch this exception.

Note that MySQL happily accepts a specific ID without requiring removal of the
AUTO_INCREMENT property on a primary key. If you use a different DBMS, please be
sure its behavior is similarly compatible or update your database table schemas
accordingly.

## Contributing to tickr_client
 
* Check out the issue tracker to make sure someone already hasn't requested it and/or contributed it.
* Fork the project.
* Start a feature/bugfix branch.
* Commit and push until you are happy with your contribution.
* Make sure to add tests for it. This is important so I don't break it in a future version unintentionally.
* Please try not to mess with the Rakefile, version, or history. If you want to have your own version, or is otherwise
necessary, that is fine, but please isolate to its own commit so I can cherry-pick around it.


