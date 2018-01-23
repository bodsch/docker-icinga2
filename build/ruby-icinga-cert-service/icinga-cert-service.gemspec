
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'cert-service/version'

Gem::Specification.new do |s|

  s.name        = 'icinga-cert-service'
  s.version     = IcingaCertService::VERSION
  s.date        = '2017-10-19'
  s.summary     = 'Icinga Certificate Service'
  s.description = 'Ruby Class to create an provide a Icinga2 Certificate for Satellites or Agents '
  s.authors     = ['Bodo Schulz']
  s.email       = 'bodo@boone-schulz.de'

  s.files       = Dir[
    'README.md',
    'LICENSE',
    'lib/**/*',
    'doc/*',
    'examples/*.rb'
  ]

  s.homepage    = 'https://github.com/bodsch/ruby-icinga-cert-service'
  s.license     = 'LGPL-2.1+'

  begin

    if( RUBY_VERSION >= '2.0' )
      s.required_ruby_version = '~> 2.0'
    elsif( RUBY_VERSION <= '2.1' )
      s.required_ruby_version = '~> 2.1'
    elsif( RUBY_VERSION <= '2.2' )
      s.required_ruby_version = '~> 2.2'
    elsif( RUBY_VERSION <= '2.3' )
      s.required_ruby_version = '~> 2.3'
    end

    if( RUBY_VERSION < '2.3' )
      s.add_dependency('ruby_dig', '~> 0')
    end

    if( RUBY_VERSION >= '2.3' )
      s.add_dependency('openssl', '~> 2.0')
    end
  rescue => e
    warn "#{$0}: #{e}"
    exit!
  end

#  s.required_ruby_version = '>= 2.3'
#  s.add_dependency('openssl', '~> 2.0')

  s.add_dependency('rest-client', '~> 2.0')
  s.add_dependency('json', '~> 2.1')

  s.add_development_dependency('rspec', '~> 0')
  s.add_development_dependency('rspec-nc', '~> 0')
  s.add_development_dependency('guard', '~> 0')
  s.add_development_dependency('guard-rspec', '~> 0')
  s.add_development_dependency('pry', '~> 0')
  s.add_development_dependency('pry-remote', '~> 0')
  s.add_development_dependency('pry-nav', '~> 0')

end

