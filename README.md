# Logstash Plugin

This is a plugin for [Logstash](https://github.com/elasticsearch/logstash).

It is fully free and fully open source. The license is Apache 2.0, meaning you are pretty much free to use it however you want in whatever way.

## Documentation

This output plugin takes a streaming telemetry event, ferrets out any numeric fields, and `PUT|POST`s events in metric format to a configured URL over HTTP. The default format of the posted content is that accepted by the `prometheus` `pushgw`, but multiple types of consumers are supported (e.g. signalfx).

HTTP headers, the URL, and the HTTP operation can all be customised. All the [HTTP mixin client](https://github.com/logstash-plugins/logstash-mixin-http_client) options and the underlying [Manticore](https://github.com/cheald/manticore) client options are supported (e.g. proxy configuration, number of parallel in flight operations, client certificate, cookie support etc).

This output plugin depends on a [sister input codec](https://github.com/cisco/logstash-codec-bigmuddy-network-telemetry) which handles compressed JSON streamed content over a stream based transport. The reverse is not true; i.e. the input codec plugin can be used with a variety of output plugins including this one.

__Note: The streaming telemetry project is work in progress, and both the on and off box components of streaming telemetry are likely to evolve at a fast pace.__

## Configuration

Sample configuration with logstash pipeline feeding `prometheus`:

```
output {
    telemetry_metrics {
	http_method => "post"
	url => "http://www.example.com:9091/metrics/jobs/xrstv2"	      
    }
}
```

A slightly more involved configuration feeding content to `signalfx`:

```
output {
    telemetry_metrics {
	http_method => "post"
	consumer => "signalfx"
	headers => {
	    "X-SF-TOKEN" => "AddYOURTokenHERE"
	}
	url => "https://ingest.signalfx.com/v2/datapoint"
	content_type => "application/json"
	proxy => "http://proxy.example.com:8080"
    }
}
```

Further documentation is provided in the [plugin source](/lib/logstash/output/telemetry_metrics.rb).

## Need Help?

Need help? Try #logstash on freenode IRC or the https://discuss.elastic.co/c/logstash discussion forum.

## Developing

### 1. Plugin Developement and Testing

#### Code
- To get started, you'll need JRuby with the Bundler gem installed.

- Create a new plugin or clone and existing from the GitHub [logstash-plugins](https://github.com/logstash-plugins) organization. We also provide [example plugins](https://github.com/logstash-plugins?query=example).

- Install dependencies
```sh
bundle install
```

#### Test

- Update your dependencies

```sh
bundle install
```

- Run tests

```sh
bundle exec rspec
```

### 2. Running your unpublished Plugin in Logstash

#### 2.1 Run in a local Logstash clone

- Edit Logstash `Gemfile` and add the local plugin path, for example:
```ruby
gem "logstash-codec-output-bigmuddy-network-telemetry-metrics", :path => "/your/local/logstash-codec-output-bigmuddy-network-telemetry-metrics"
```
- Install plugin
```sh
bin/plugin install --no-verify
```

At this point any modifications to the plugin code will be applied to this local Logstash setup. After modifying the plugin, simply rerun Logstash.

#### 2.2 Run in an installed Logstash

You can use the same **2.1** method to run your plugin in an installed Logstash by editing its `Gemfile` and pointing the `:path` to your local plugin development directory or you can build the gem and install it using:

- Build your plugin gem
```sh
gem build logstash-codec-output-bigmuddy-network-telemetry-metrics.gemspec
```
- Install the plugin from the Logstash home
```sh
bin/plugin install /your/local/plugin/logstash-codec-output-bigmuddy-network-telemetry-metrics.gem
```
- Start Logstash and proceed to test the plugin

## Contributing

All contributions are welcome: ideas, patches, documentation, bug reports, complaints, and even something you drew up on a napkin.

Programming is not a required skill. Whatever you've seen about open source and maintainers or community members  saying "send patches or die" - you will not see that here.

It is more important to the community that you are able to contribute.

For more information about contributing, see the [CONTRIBUTING](https://github.com/elasticsearch/logstash/blob/master/CONTRIBUTING.md) file.