## Watchbot

[![Code Climate](https://codeclimate.com/repos/5501fd41e30ba0588f0006d4/badges/e3ad415924b42587b54a/gpa.svg)](https://codeclimate.com/repos/5501fd41e30ba0588f0006d4/feed)
[![Test Coverage](https://codeclimate.com/repos/5501fd41e30ba0588f0006d4/badges/e3ad415924b42587b54a/coverage.svg)](https://codeclimate.com/repos/5501fd41e30ba0588f0006d4/feed)

Subsystem that continuously monitors web links to verify that they are still valid/active. We call this component the watchbot. We are aiming for simplicity and only supporting the Bridge OOEW 0.5 use case, namely: verifying that media links are present or absent.

The proposed architecture is a self-contained system that receives links from clients and monitors those links on behalf of those clients. The monitoring activity is scheduled by the watchbot according to a configured schedule. The act of monitoring consists of verifying certain conditions (such as checking for HTTP 404 on a link) and notifying the client via a web hook in case the condition is true. Some conditions are general to all links, while other only apply to certain links (e.g. based on their host).

The client communicates with the watchbot via a REST interface:

* Add/remove a link: `POST/DELETE /link/:link`

The watchbot is configured with the following options:

```
webhook: {
  /**
   * A callback URL on the client to notify of a condition being met on a certain link. The endpoint signature is as follows:
   * POST :callback_url { 
   * link: original link for which condition was met,
   * condition: the name of the condition that was verified,
   * timestamp: the time at which the condition was verified
   * }
   *
   * The HTTP header X-Watchbot-Signature is set to a hash signature of the post body. 
   * The :secret_token configuration is used to compute the signature.
   * Refer to https://developer.github.com/webhooks/securing/ [^] for implementation details
   */
callback_url: 
secret_token:
},
schedule: [
/**
 * Schedule of verifying conditions.
 * For each action, the conditions are verified every first :interval, until the time elapsed exceeds :to. 
 * At this point, the schedule moves to the next :interval, until the time elapsed exceeds the second :to, and so on.
 * If the last entry only contains :interval, the conditions will continue to be verified forever at that interval.
 */
{ to: , interval: },
{ ... },
  ],
  conditions: [
  /**
   * Conditions to verify.
   * Each condition verification is applied to each link that matches :linkRegex.
   * :condition(:link) -> :boolean is a function that returns true when the condition applies, false when it doesn't apply.
   * If the condition applies and :removeIfApplies is true, then the link should be removed from the database.
   */
{ 
linkRegex:
condition:
removeIfApplies:
},
{ ... }
]
```

The only condition needed to start is a HTTP 404 checker that applies to all hosts.

Installation

* Copy `config/mongoid.yml.example` to `config/mongoid.yml` and configure your database
* Copy `config/initializers/errbit.rb.example` to `config/initializers/errbit.rb` and configure Errbit
* Copy `config/watchbot.yml.example` to `config/watchbot.yml` and configure your application
* Create delayed job indexes by running: `script/rails runner 'Delayed::Backend::Mongoid::Job.create\_indexes'`

Administrative tasks

There are some rake tasks to perform administrative actions. For example:

* `rake watchbot:api\_keys:delete\_expired`: Remove expired keys from the database
* `rake watchbot:api\_keys:create`: Create a new API key
