#!/usr/bin/env ruby
#
# 05.10.2016 - Bodo Schulz
#
#
# v2.1.0

# -----------------------------------------------------------------------------

require 'ruby_dig' if RUBY_VERSION < '2.3'

require 'sinatra/base'
require 'sinatra/basic_auth'
require 'json'
require 'yaml'

require_relative '../lib/cert-service'
require_relative '../lib/logging'

# -----------------------------------------------------------------------------

config = {
  icinga_master: 'localhost'
}

ics = IcingaCertService::Client.new(config)

# -----------------------------------------------------------------------------
