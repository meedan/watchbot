## Watchbot

[![Code Climate](https://codeclimate.com/repos/5501fd41e30ba0588f0006d4/badges/e3ad415924b42587b54a/gpa.svg)](https://codeclimate.com/repos/5501fd41e30ba0588f0006d4/feed)
[![Test Coverage](https://codeclimate.com/repos/5501fd41e30ba0588f0006d4/badges/e3ad415924b42587b54a/coverage.svg)](https://codeclimate.com/repos/5501fd41e30ba0588f0006d4/feed)

### Introduction

Subsystem that continuously monitors web links to verify certain conditions and states.

The architecture is a self-contained system that receives links from clients and monitors those links on behalf of those clients. The monitoring activity is scheduled by the Watchbot according to a configured schedule. The act of monitoring consists of verifying certain conditions (such as checking for HTTP 404 on a link) and notifying the client via a web hook in case the condition is true. Some conditions are general to all links, while other only apply to certain links (e.g. based on their host).

![Workflow](doc/workflow.png?raw=true "Workflow")

### Checkers

#### 404 Checker

This checker verifies if the link is still online or not. It returns `true` if the HTTP response for the link is on the 400 range.

#### Google Spreadsheet Updated Checker

This checker verifies if a Google Spreadsheet was updated or not. This is done based on a MD5 hash of the its rows. If the hash changes
within 30 seconds, it's because probably someone is still editing the spreadsheet, so on this case it returns false.

#### Facebook Likes & Shares

This checker verifies the number of likes and shares of a Facebook post, using Facebook Graph API. Returns false if the numbers haven't changed since the last check or if it was not possible to connect to Facebook API. Returns a hash `{ :likes, :shares }` otherwise.

#### Twitter Favorites & Retweets (API)

This checker verifies the number of favorites (likes) and retweets (shares) of a tweet, using Twitter REST API. Returns false if the numbers haven't changed since the last check or if it was not possible to connect to Twitter API. Returns a hash `{ :likes, :shares }` otherwise.

#### Twitter Favorites & Retweets (HTML)

This checker verifies the number of favorites (likes) and retweets (shares) of a tweet, by scraping the HTML page of the tweet. Returns false if the numbers haven't changed since the last check or if it was not possible to parse the HTML page. Returns a hash `{ :likes, :shares }` otherwise.

### How to write your own checker

In order to write a new checker, you just need to:

1. Add the new condition to the `conditions` property in your configuration file
2. Write a new method with your condition name under the module `LinkCheckers` (this method should return `false` in order to not notify the client or any other thing, which will be notified to the client, and can write/read link data on its `data` attribute, which is a hash)

### How to communicate with the Watchbot

The client communicates with the Watchbot via a REST interface:

* Add a link: `POST /links {"url":"link"}` which returns `{"type":"success"}` in case of success or `{"type":"error","data":{"message":"Error message","code":"error code"}}` otherwise.

* Add many links: `POST /links/bulk {"url1":"link1","url2","link2","url3","link3",...,"urln":"linkn"}` which returns `{"type":"success"}` in case of success with a message that says how many items were created successfully and how many items failed.

* Remove a link: `DELETE /links/:link` which returns `{"type":"success"}` in case of success or `{"type":"error","data":{"message":"Error message","code":"error code"}}` otherwise.

* Remove many links: `DELETE /links/bulk {"url1":"link1","url2","link2","url3","link3",...,"urln":"linkn"}` which returns `{"type":"success"}` in case of success

Check the script at `scripts/test.sh` to see how these endpoints can be called.

When a condition is verified, the client is notified through a webhook. An example simple client written in Sinatra can be found at `scripts/sinatra.rb`, which runs by default at `http://localhost:4567` and has a `/payload` API enpoint to receive the notifications from the Watchbot. It's necessary to setup a `secret_token` on both client and server in order to verify the communication.

The example client webhook can be run by: `SECRET_TOKEN=mysecrettoken ruby scripts/sinatra.rb`

When notified, it will print something like this on its log:

```
JSON received: {"link"=>"http://link.link", "condition"=>{}, "timestamp"=>1427390618, "data"=>{}}
127.0.0.1 - - [26/Mar/2015 14:23:38] "POST /payload HTTP/1.1" 200 - 0.0075
```

In case of an invalid secret token, it will just return an error 500:

```
127.0.0.1 - - [26/Mar/2015 14:21:42] "POST /payload HTTP/1.1" 500 24 0.0061
```

### Configuration

The Watchbot is configured with the following options (at `config/applications/<environment>/application.yml`):

```yaml
webhook:
  # A callback URL on the client to notify of a condition being met on a certain link. The endpoint signature is as follows:
  # POST :callback_url { 
  #   link: original link for which condition was met,
  #   condition: the name of the condition that was verified,
  #   timestamp: the time at which the condition was verified
  #   data: an object with any information returned by the checker
  # }
  # 
  # The HTTP header X-Watchbot-Signature is set to a hash signature of the post body. 
  # The :secret_token configuration is used to compute the signature.
  # Refer to https://developer.github.com/webhooks/securing/ [^] for implementation details
  callback_url: http://localhost:4567/payload
  secret_token: mysecrettoken
schedule: [
  # Schedule of verifying conditions.
  # For each action, the conditions are verified every first :interval, until the time elapsed exceeds :to. 
  # At this point, the schedule moves to the next :interval, until the time elapsed exceeds the second :to, and so on.
  # If the last entry only contains :interval, the conditions will continue to be verified forever at that interval.
  { to: 172800, interval: '*/5 * * * *' }, # 2 days old - check every 5 minutes
  { to: 604800, interval: '0 * * * *' },   # 7 days old - check every hour
  { interval: '0 3 * * *' }                # More than 7 days old - check once a day
]
conditions: [
  # Conditions to verify.
  # Each condition verification is applied to each link that matches :linkRegex.
  # :condition(:link) -> :boolean is a function that returns true when the condition applies, false when it doesn't apply.
  # If the condition applies and :removeIfApplies is true, then the link should be removed from the database.
  { 
    linkRegex: '^https?:\/\/(www\.)?(twitter|instagram)\.com\/',
    condition: check404,
    removeIfApplies: true
  },
  { 
    linkRegex: '^https?:\/\/docs\.google\.com\/',
    condition: check_google_spreadsheet_updated,
    removeIfApplies: false
  }
]
settings:
  google_email:
  google_password:
  # Other settings required by checkers go here...
```

### Installation

* Copy `config/mongoid.yml.example` to `config/mongoid.yml` and configure your database
* Copy `config/sidekiq.yml.example` to `config/sidekiq.yml` and configure Sidekiq
* Copy `config/initializers/errbit.rb.example` to `config/initializers/errbit.rb` and configure Errbit
* Create the applications on `config/applications/<environment>` (check examples under `config/applications/example`)
* Install the gems: `bundle install`
* Start the server
* Start Sidekiq: `bundle exec sidekiq -d` (you can monitor Sidekiq by going to http://watchbot-server/sidekiq)

### Administrative tasks

There are some rake tasks to perform administrative actions. For example:

* `rake watchbot:api_keys:delete_expired`: Remove expired keys from the database
* `rake watchbot:api_keys:create application=<application name>`: Create a new API key for the application

### Automated tests

Run the test suite and coverage by calling `rake test:coverage`.

### Documentation

Provided by [Swagger](http://swagger.io). You can access it by going to http://watchbot-server/api and you can update it by running `rake swagger:docs`.
