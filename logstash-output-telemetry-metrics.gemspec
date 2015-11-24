Gem::Specification.new do |s|
  s.name = 'logstash-output-telemetry-metrics'
  s.version         = '0.9.0'
  s.licenses = ['Apache License (2.0)']
  s.summary = "This output plugin extracts metrics from cisco telemetry, and posts over http."
  s.description = "This gem is a logstash plugin required to be installed on top of the Logstash core pipeline using $LS_HOME/bin/plugin install gemname. This gem is not a stand-alone program"
  s.authors = ["cisco"]
  s.email = 'ccassar@cisco.com'
  s.homepage = "http://www.cisco.com/"
  s.require_paths = ["lib"]

  # Files
  s.files = Dir['lib/**/*','spec/**/*','vendor/**/*','*.gemspec','*.md','CONTRIBUTORS','Gemfile','LICENSE','NOTICE.TXT']

   # Tests
  s.test_files = s.files.grep(%r{^(test|spec|features)/})

  # Special flag to let us know this is actually a logstash plugin
  s.metadata = { "logstash_plugin" => "true", "logstash_group" => "output" }

  # Gem dependencies
  s.add_runtime_dependency "logstash-core", '>= 1.4.0', '< 3.0.0'
  s.add_runtime_dependency "logstash-mixin-http_client", ">= 1.0.0", "< 3.0.0"
  s.add_runtime_dependency "manticore", "< 0.5.0"

  s.add_development_dependency 'logstash-devutils'
end
