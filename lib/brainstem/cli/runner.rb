require 'brainstem/api_docs/builder'
Dir.glob(File.expand_path('../../api_docs/sinks/**/*.rb', __FILE__)).each { |f| require f }
