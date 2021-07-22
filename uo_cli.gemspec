require_relative 'lib/uo_cli/version'

Gem::Specification.new do |spec|
  spec.name            = 'urbanopt-cli'
  spec.version         = URBANopt::CLI::VERSION
  spec.authors         = ['Nathan Moore']
  spec.email           = ['nathan.moore@nrel.gov']
  spec.license         = 'Nonstandard'

  spec.summary         = 'Command Line Interface for URBANopt district building simulations'
  spec.description     = 'Interfacing with URBANopt'
  spec.homepage        = 'https://docs.urbanopt.net/'

  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = 'https://rubygems.org/'
    spec.metadata['homepage_uri'] = spec.homepage
    spec.metadata['source_code_uri'] = 'https://github.com/urbanopt/urbanopt-cli'
    spec.metadata['documentation_uri'] = 'https://docs.urbanopt.net/'
    spec.metadata['bug_tracker_uri'] = 'https://github.com/urbanopt/urbanopt-cli/issues'
  else
    raise 'RubyGems 2.0 or newer is required to protect against public gem pushes.'
  end

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.files += Dir.glob('example_files/**')
  spec.bindir = 'bin'
  spec.executables = ['uo']
  spec.require_paths = ['lib', 'example_files']
  spec.required_ruby_version = '~> 2.7.0'

  #   use specific versions of urbanopt and openstudio dependencies while under heavy development
  spec.add_runtime_dependency 'optimist', '~> 3'
  spec.add_runtime_dependency 'urbanopt-geojson', '~> 0.6.3'
  spec.add_runtime_dependency 'urbanopt-reporting', '~> 0.4.1'
  spec.add_runtime_dependency 'urbanopt-scenario', '~> 0.6.2'
  spec.add_runtime_dependency 'urbanopt-reopt', '~> 0.6.1'
  spec.add_runtime_dependency 'urbanopt-rnm-us', '~> 0.1.0'

  spec.add_development_dependency 'bundler', '>= 2.1.0'
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'rspec', '~> 3.7'
  spec.add_development_dependency 'rubocop', '~> 1.15.0'
  spec.add_development_dependency 'rubocop-performance', '~> 1.11.3'
  spec.add_development_dependency 'rubocop-checkstyle_formatter', '~> 0.4.0'
end
