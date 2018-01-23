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

module Sinatra
  class CertServiceRest < Base
    register Sinatra::BasicAuth

    include Logging

    @icinga_master        = ENV.fetch('ICINGA_HOST'        , nil)
    @icinga_api_port      = ENV.fetch('ICINGA_API_PORT'    , 5665 )
    @icinga_api_user      = ENV.fetch('ICINGA_API_USER'    , 'root' )
    @icinga_api_password  = ENV.fetch('ICINGA_API_PASSWORD', 'icinga' )
    @rest_service_port    = ENV.fetch('REST_SERVICE_PORT'  , 8080 )
    @rest_service_bind    = ENV.fetch('REST_SERVICE_BIND'  , '0.0.0.0' )
    @basic_auth_user      = ENV.fetch('BASIC_AUTH_USER'    , 'admin')
    @basic_auth_pass      = ENV.fetch('BASIC_AUTH_PASS'    , 'admin')

    configure do
      set :environment, :production

      # default configuration
      @rest_service_port  = 8080
      @rest_service_bind  = '0.0.0.0'

      if( File.exist?('/etc/rest-service.yaml') )

        config = YAML.load_file('/etc/rest-service.yaml')

        @icinga_master       = config.dig('icinga', 'server')
        @icinga_api_port     = config.dig('icinga', 'api', 'port')  || 5665
        @icinga_api_user     = config.dig('icinga', 'api', 'user')  || 5665
        @icinga_api_password = config.dig('icinga', 'api', 'password')  || 5665
        @rest_service_port   = config.dig('rest-service', 'port')   || 8080
        @rest_service_bind   = config.dig('rest-service', 'bind')   || '0.0.0.0'
        @basic_auth_user     = config.dig('basic-auth', 'user')     || 'admin'
        @basic_auth_pass     = config.dig('basic-auth', 'password') || 'admin'
      else
        puts 'no configuration exists, use default settings'
      end
    end

    set :logging, true
    set :app_file, caller_files.first || $PROGRAM_NAME
    set :run, proc { $PROGRAM_NAME == app_file }
    set :dump_errors, true
    set :show_exceptions, true
    set :public_folder, '/var/www/'

    set :bind, @rest_service_bind
    set :port, @rest_service_port.to_i

    # -----------------------------------------------------------------------------

    error do
      msg = "ERROR\n\nThe cert-rest-service has nasty error - " + env['sinatra.error']

      msg.message
    end

    # -----------------------------------------------------------------------------

    before do
      content_type :json
    end

    before '/v2/*/:host' do
      request.body.rewind
      @request_paylod = request.body.read
    end

    # -----------------------------------------------------------------------------

    # configure Basic Auth
    authorize 'API' do |username, password|
      username == @basic_auth_user && password == @basic_auth_pass
    end

    # -----------------------------------------------------------------------------

    config = {
      icinga: {
        server: @icinga_master,
        api: {
          port: @icinga_api_port,
          user: @icinga_api_user,
          password: @icinga_api_password,
          pki_path: @icinga_api_pki_path,
          node_name: @icinga_api_node_name
        }
      }
    }

    ics = IcingaCertService::Client.new(config)

    get '/v2/health-check' do
      status 200
      'healthy'
    end

    get '/v2/icinga-version' do
      status 200
      result   = ics.icinga_version
      result + "\n"
    end

    # curl \
    #  -u "foo:bar" \
    #  --request GET \
    #  --header "X-API-USER: cert-service" \
    #  --header "X-API-KEY: knockknock" \
    #  http://$REST-SERVICE:8080/v2/request/$HOST-NAME
    #
    protect 'API' do
      get '/v2/request/:host' do
        result   = ics.create_certificate(host: params[:host], request: request.env)
        result_status = result.dig(:status).to_i

        status result_status

        JSON.pretty_generate(result) + "\n"
      end
    end

    # curl \
    #  -u "foo:bar" \
    #  --request POST \
    #  http://$REST-SERVICE:8080/v2/ticket/$HOST-NAME
    #
    protect 'API' do
      post '/v2/ticket/:host' do
        status 200

        result = ics.create_ticket(host: params[:host])

        JSON.pretty_generate(result) + "\n"
      end
    end

    # curl \
    #  -u "foo:bar" \
    #  --request GET \
    #  http://$REST-SERVICE:8080/v2/validate/$CHECKSUM
    #
    protect 'API' do
      get '/v2/validate/:checksum' do
        result = ics.validate_certificate(checksum: params[:checksum])
        result_status = result.dig(:status).to_i

        status result_status
        content_type :json
        JSON.pretty_generate(result) + "\n"
      end
    end


    # curl \
    #  -u "foo:bar" \
    #  --request GET \
    #  --header "X-API-USER: cert-service" \
    #  --header "X-API-KEY: knockknock" \
    #  --header "X-CHECKSUM: ${checksum}" \
    #  --output /tmp/$HOST-NAME.tgz \
    #  http://$REST-SERVICE:8080/v2/cert/$HOST-NAME
    #
    protect 'API' do
      get '/v2/cert/:host' do
        result = ics.check_certificate( host: params[:host], request: request.env )

        logger.debug(result)

        result_status = result.dig(:status).to_i

        if result_status == 200

          path      = result.dig(:path)
          file_name = result.dig(:file_name)

          status result_status

          send_file(format('%s/%s', path, file_name), filename: file_name, type: 'Application/octet-stream')
        else

          status result_status

          JSON.pretty_generate(result) + "\n"
        end
      end
    end

    # curl \
    #  -u "foo:bar" \
    #  --request GET \
    #  --header "X-API-USER: cert-service" \
    #  --header "X-API-KEY: knockknock" \
    #  --header "X-CHECKSUM: ${checksum}" \
    #  --output /tmp/ca.crt \
    #  http://$REST-SERVICE:8080/v2/master-ca
    #
    protect 'API' do
      get '/v2/master-ca' do

        path= '/var/lib/icinga2'
        file_name = 'ca.crt'
        if( File.exist?(format('%s/%s', path, file_name) ) )
          status 200
          send_file(format('%s/%s', path, file_name), filename: file_name, type: 'Application/octet-stream')
        else

          status 404

          JSON.pretty_generate('no ca file found') + "\n"
        end
      end
    end

    # curl \
    #  -u "foo:bar" \
    #  --request POST \
    #  --header "X-API-USER: cert-service" \
    #  --header "X-API-KEY: knockknock" \
    #  http://$REST-SERVICE:8080/v2/sign/$HOST-NAME
    #
    protect 'API' do
      get '/v2/sign/:host' do
        status 200

        result = ics.sign_certificate(host: params[:host], request: request.env)

        JSON.pretty_generate(result) + "\n"
      end
    end


    not_found do
      jj = {
        'meta' => {
          'code' => 404,
          'message' => 'Request not found.'
        }
      }
      content_type :json
      JSON.pretty_generate(jj)
    end

    # -----------------------------------------------------------------------------
    run! if app_file == $PROGRAM_NAME
    # -----------------------------------------------------------------------------
  end
end
