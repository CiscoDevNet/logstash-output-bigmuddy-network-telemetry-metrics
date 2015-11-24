# encoding: utf-8
require "logstash/outputs/base"
require "logstash/namespace"
require "logstash/plugin_mixins/http_client"

class LogStash::Outputs::TelemetryMetrics < LogStash::Outputs::Base
  include LogStash::PluginMixins::HttpClient
  #
  # This output plugin takes a telemetry event and `PUT|POST`s events
  # in metric format to a configured URL (default format is
  # prometheus, but multiple types of consumers supported). Headers
  # can be customised like in the generic http output plugin.
  #
  # This output plugin only supports telemetry learnt over JSON, not
  # GPB. This is because with GPB, there is no mechanical way to
  # extract the key from the data without access to the model.
  # With JSON path serves as instance key (in the worst case where is
  # not extracted while flattening).
  #
  config_name "telemetry_metrics"

  # URL to use
  config :url, :validate => :string, :required => :true

  # What verb to use - only put and post are supported
  config :http_method, :validate => ["put", "post"], :default => "post"

  # Custom headers
  #
  # format is `headers => {"X-My-Header" => "Value"}]
  config :headers, :validate => :hash

  # Content type; note version indicates prometheus text format (to
  # match default consumer) version as per Prometheus Client Data
  # Exposition Format
  config :content_type, :validate => :string, :default => "plain/text; version=0.0.4; charset=utf-8"

  #
  # Metric consumer?
  #
  config :consumer, :validate => ["prometheus", "signalfx"], :default => "prometheus"

  #
  # Register output
  #
  public
  def register
    require "uri"

    @logger.debug? &&
      @logger.debug("Registering telemetry metrics output plugin",
                    :consumer => @consumer.to_s)

    #
    # As with http output plugin, we attempt to multiplex
    # pushes. (Risk of out of order deliveries being dropped, by some
    # consumers).
    #
    @request_tokens = SizedQueue.new(@pool_max)
    @pool_max.times {|t| @request_tokens << true }

  end

  public
  def receive(event)
    return unless output?(event)

    #
    # Extract URL and body from event.
    #
    url_postpend, body = extract_time_series(event.to_hash)
    return if body.nil?

    # Postpend if necessary
    url = @url + url_postpend

    unless defined? @headers
      @headers =  {}
    end
    @headers["Content-Type"] = @content_type

    # Block waiting for a token, if necessary
    token = @request_tokens.pop

    @logger.debug? &&
      @logger.debug("HTTP push", :http_method => @http_method, :url => url,
                    :headers => @headers, :body => body)

    request = client.send(@http_method, event.sprintf(url), :body => body,
                          :headers => @headers, :async => true)

    #
    # Again, as per the http output plugin, it appears that if a list
    # is maintained for a service we do not use, and we need to clean
    # it up explicitly.
    #
    client.clear_pending

    request.on_complete do
      #
      # Return token to pool now that request has been
      # handled (rememeber how we held one while handling request).
      #
      @request_tokens << token
      @logger.debug? &&
        @logger.debug("Rxed response HTTP code",
                      :response_code => request.code,
                      :response_message => request.message,
                      :response => request.to_s)
    end

    request.on_success do |response|
      if response.code < 200 || response.code > 299
        @logger.debug? &&
          @logger.debug("Encountered non-200 HTTP code",
                        :response_code => response.code,
                        :url => url,
                        :event => event)
      end
    end

    request.on_failure do |exception|
      @logger.debug? &&
        @logger.debug("Could not send",
                      :url => url,
                      :method => @http_method,
                      :body => body,
                      :headers => headers,
                      :message => exception.message,
                      :class => exception.class.name,
                      :backtrace => exception.backtrace)
    end

    #
    # Schedule work
    #
    @method ||= client.executor.java_method(:submit, [java.util.concurrent.Callable.java_class])
    @method.call(request)

  rescue Exception => e
    @logger.warn("Exception pushing http request",
                 :event => event.to_s, :exception => e,
                 :stacktrace => e.backtrace)
    
  end # def receive

 def extract_one_metric(hash, timestamp, metric, value)

   if not value.is_a? Numeric
     return nil
   end

   case @consumer
   when "signalfx"

     return {
       'metric' => metric,
       'dimensions' => {
         'path' => hash['identifier'] + "_" + hash['path'].gsub(/[^a-zA-Z0-9_:]/,'_'),
         'policy' => hash["policy_name"]},
       'value'=> value,
       'timestamp' => timestamp}.to_json

   when "prometheus"

     return metric + "{policy=\"" + hash["policy_name"] + "\",version=\"" + hash["version"].to_s + "\"} " + value.to_s + " " + timestamp.to_s + "\n"

   else
      #
      # No further post processing
      #
   end

 end # def extract_one_metric

 def collapse(x, branch = nil)
   if x.is_a? Hash
     x.map do |key, value|
       if branch
         collapse value, "#{branch}_#{key}"
       else
         collapse value, "#{key}"
       end
     end.reduce(&:merge)
   else
     {branch => x}
   end
 end

 def extract_one_or_many_metrics(hash, timestamp, metrictype, delimeter)


     if hash['content'].is_a? Numeric
       metriccontent = extract_one_metric(hash, timestamp, metrictype,
                                          hash['content'])
     elsif hash['content'].is_a? Hash

       flatcontent = collapse(hash['content'])
       @logger.debug? &&
         @logger.debug("Content a hash", :flatcontent => flatcontent)

       #
       # Reject nonnumeric fields (note we still don't look into
       # arrays.
       #
       keepnumeric = flatcontent.reject {|k,v| not v.is_a? Numeric}

       metriccontent = keepnumeric.collect do |k,v|
         extract_one_metric(hash, timestamp, k, v)
       end.join(delimeter)
     else
        @logger.debug? &&
          @logger.debug("Content is not a hash or a number")
       return ""
     end

   return metriccontent

 end # def extract_one_or_many_metrics

 def extract_time_series(hash)

   return nil, nil if hash['content'].nil? ||
     hash['identifier'].nil? ||
     hash['type'].nil? ||
     hash['policy_name'].nil? ||
     hash['version'].nil? ||
     hash['path'].nil? ||
     hash["end_time"].nil?

   case @consumer
   when "signalfx"
     metriccontent = extract_one_or_many_metrics(hash,
                                                 hash["end_time"],
                                                 hash['type'].gsub(/[^a-zA-Z0-9_:]/,'_'),
                                                 ',')
     #
     # We do not want to be picking gauge versus counter versus metric
     # counter here :-( We have to.
     #
     return "", "{\"gauge\": [ #{metriccontent} ]}"

   when "prometheus"
     metriccontent = extract_one_or_many_metrics(hash,
                                                 hash["end_time"],
                                                 hash['type'].gsub(/[^a-zA-Z0-9_:]/,'_'),
                                                 '')
     metricname = (hash['identifier'] + "_" + hash['path']).gsub(/[^a-zA-Z0-9_:]/,'_')
     return "/instances/" + metricname, metriccontent

   else
      #
      # No further post processing
      #
   end

   return "", ""
 end # def extract_time_series

end
