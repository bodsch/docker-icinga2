
require 'open3'

require_relative 'monkey'

module IcingaCertService

  module CertificateHandler

    # create a certificate
    #
    # @param [Hash, #read] params
    # @option params [String] :host
    # @option params [Hash] :request
    #
    # @example
    #    create_certificate( host: 'icinga2-satellite', request: { 'HTTP_X_API_USER => 'admin', HTTP_X_API_PASSWORD' => 'admin' } } )
    #
    # @return [Hash, #read]
    #  * :status [Integer] 200 for successful, or 500 for an error
    #  * :master_name [String] the Name of the Icinga2-master (need to configure the satellite correctly)
    #  * :master_ip [String] the IP of the Icinga2-master (need to configure the satellite correctly)
    #  * :checksum [String] a created Checksum to retrive the certificat archive
    #  * :timestamp [Integer] a timestamp for the created archive
    #  * :timeout [Integer] the timeout for the created archive
    #  * :file_name [String] the archive Name
    #  * :path [String] the Path who stored the certificate archive
    #
    def create_certificate( params )

      host         = params.dig(:host)
      api_user     = params.dig(:request, 'HTTP_X_API_USER')
      api_password = params.dig(:request, 'HTTP_X_API_PASSWORD')

      return { status: 500, message: 'no hostname' } if( host.nil? )
      return { status: 500, message: 'missing API Credentials - API_USER' } if( api_user.nil?)
      return { status: 500, message: 'missing API Credentials - API_PASSWORD' } if( api_password.nil? )

      password = read_api_credentials( api_user: api_user )

      return { status: 500, message: 'wrong API Credentials' } if( password.nil? || api_password != password )

      if( @icinga_master.nil? )
        begin
          server_name = Socket.gethostbyname(Socket.gethostname).first
        rescue => e
          logger.error(e)

          server_name = @icinga_master
        else
          server_ip    = IPSocket.getaddress(Socket.gethostname)
        end
      else
        server_name = @icinga_master

        begin
          server_ip    = IPSocket.getaddress(server_name)
        rescue => e
          logger.error(server_name)
          logger.error(e)

          server_ip = '127.0.0.1'
        end
      end

      pki_base_directory = '/etc/icinga2/pki'
      pki_base_directory = '/var/lib/icinga2/certs' if( @icinga_version == '2.8' )

      return { status: 500, message: 'no PKI directory found. Please configure first the Icinga2 Master!' } if( pki_base_directory.nil? )

      pki_master_key = format('%s/%s.key', pki_base_directory, server_name)
      pki_master_csr = format('%s/%s.csr', pki_base_directory, server_name)
      pki_master_crt = format('%s/%s.crt', pki_base_directory, server_name)
      pki_master_ca  = format('%s/ca.crt', pki_base_directory)

      return { status: 500, message: 'no PKI directory found. Please configure first the Icinga2 Master!' } unless( File.exist?(pki_base_directory) )

      zone_base_directory = '/etc/icinga2/zone.d'

      FileUtils.mkpath( format('%s/global-templates', zone_base_directory) )
      FileUtils.mkpath( format('%s/%s', zone_base_directory, host) )

      #
      unless File.exist?(format('%s/global-templates/services.conf', zone_base_directory) )

        if( File.exist?('/etc/icinga2/conf.d/services.conf') )
          FileUtils.mv('/etc/icinga2/conf.d/services.conf', format('%s/global-templates/services.conf', zone_base_directory))
        else
          logger.error('missing services.conf under /etc/icinga2/conf.d')
        end
      end

      logger.debug(format('search PKI files for the Master \'%s\'', server_name))

      if( !File.exist?(pki_master_key) || !File.exist?(pki_master_csr) || !File.exist?(pki_master_crt) )
        logger.error('missing file')
        logger.debug(pki_master_key)
        logger.debug(pki_master_csr)
        logger.debug(pki_master_crt)

        return { status: 500, message: format('missing PKI for Icinga2 Master \'%s\'', server_name) }
      end

      tmp_host_directory = format('%s/%s', @tmp_directory, host)
      # uid         = File.stat('/etc/icinga2/conf.d').uid
      # gid         = File.stat('/etc/icinga2/conf.d').gid

      FileUtils.rmdir(tmp_host_directory) if(File.exist?(tmp_host_directory))
      FileUtils.mkpath(tmp_host_directory) unless File.exist?(tmp_host_directory)
      FileUtils.chmod_R(0o777, @tmp_directory) if File.exist?(tmp_host_directory)

      return { status: 500, message: 'can\'t create temporary directory' } unless File.exist?(tmp_host_directory)

      salt = Digest::SHA256.hexdigest(host)

      pki_satellite_key = format('%s/%s.key', tmp_host_directory, host)
      pki_satellite_csr = format('%s/%s.csr', tmp_host_directory, host)
      pki_satellite_crt = format('%s/%s.crt', tmp_host_directory, host)
      pki_ticket       = '%PKI_TICKET%'

      commands = []

      # icinga2 pki new-cert --cn $node --csr $node.csr --key $node.key
      # icinga2 pki sign-csr --csr $node.csr --cert $node.crt
      commands << format('icinga2 pki new-cert --cn %s --key %s --csr %s', host, pki_satellite_key, pki_satellite_csr)
      commands << format('icinga2 pki sign-csr --csr %s --cert %s', pki_satellite_csr, pki_satellite_crt)

      if( @icinga_version == '2.7' )
        commands << format('icinga2 pki save-cert --key %s --cert %s --trustedcert %s/trusted-master.crt --host %s', pki_satellite_key, pki_satellite_crt, tmp_host_directory, server_name)
        commands << format('icinga2 pki ticket --cn %s --salt %s', server_name, salt)
        commands << format('icinga2 pki request --host %s --port 5665 --ticket %s --key %s --cert %s --trustedcert %s/trusted-master.crt --ca %s', server_name, pki_ticket, pki_satellite_key, pki_satellite_crt, tmp_host_directory, pki_master_ca)
      end

      pki_ticket = nil
      next_command = nil

      commands.each_with_index do |c, index|

        next_command = commands[index + 1]
        result       = exec_command(cmd: c)
        exit_code    = result.dig(:code)
        exit_message = result.dig(:message)

        logger.debug( format( ' => %s', c ) )
        logger.debug( format( '    - [%s]  %s', exit_code, exit_message ) )

        if( exit_code != true )
          logger.error(exit_message)
          logger.error(format('  command \'%s\'', c))
          logger.error(format('  returned with exit-code \'%s\'', exit_code))

          return { status: 500, message: format('Internal Error: \'%s\' - \'cmd %s\'', exit_message, c) }
        end

        if( exit_message =~ %r{/information\//} )
          # logger.debug( 'no ticket' )
        else
          pki_ticket   = exit_message.strip
          next_command = next_command.gsub!('%PKI_TICKET%', pki_ticket) unless( next_command.nil? )
        end
      end

      FileUtils.cp( pki_master_ca, format('%s/ca.crt', tmp_host_directory) )

      #     # TODO
      # Build Checksum
      #       Dir[ sprintf( '%s/*', tmp_host_directory ) ].each do |file|
      #         if( File.directory?( file ) )
      #           next
      #         end
      #
      #         Digest::SHA2.hexdigest( File.read( file ) )
      #       end
      #

      # create TAR File
      io = tar(tmp_host_directory)
      # and compress
      gz = gzip(io)

      # write to filesystem

      archive_name = format('%s/%s.tgz', @tmp_directory, host)

      begin
        file = File.open(archive_name, 'w')

        file.binmode
        file.write(gz.read)
      rescue IOError => e
        # some error occur, dir not writable etc.
        logger.error(e)
      ensure
        file.close unless file.nil?
      end

      checksum  = Digest::SHA2.hexdigest(File.read(archive_name))
      timestamp = Time.now
      timeout   = timestamp.add_minutes(10)

      logger.debug(format(' timestamp : %s', timestamp.to_datetime.strftime('%d-%m-%Y %H:%M:%S')))
      logger.debug(format(' timeout   : %s', timeout.to_datetime.strftime('%d-%m-%Y %H:%M:%S')))

      # store datas in-memory
      #
      save(checksum, timestamp: timestamp, timeout: timeout, host: host)

      # remove the temporary data
      #
      FileUtils.rm_rf(tmp_host_directory)

      {
        status: 200,
        master_name: server_name,
        master_ip: server_ip,
        checksum: checksum,
        timestamp: timestamp.to_i,
        timeout: timeout.to_i,
        file_name: format('%s.tgz', host),
        path: @tmp_directory
      }
    end

    # create a icinga2 Ticket
    # (NOT USED YET)
    #
    def create_ticket( params )

      host = params.dig(:host)

      return { status: 500, message: 'no hostname to create a ticket' } if( host.nil? )

      server_name  = Socket.gethostbyname(Socket.gethostname).first
      server_ip    = IPSocket.getaddress(Socket.gethostname)

      # logger.debug(host)

      file_name = '/etc/icinga2/constants.conf'

      file     = File.open(file_name, 'r')
      contents = file.read

      regexp_long = / # Match she-bang style C-comment
        \/\*          # Opening delimiter.
        [^*]*\*+      # {normal*} Zero or more non-*, one or more *
        (?:           # Begin {(special normal*)*} construct.
          [^*\/]      # {special} a non-*, non-\/ following star.
          [^*]*\*+    # More {normal*}
        )*            # Finish "Unrolling-the-Loop"
        \/            # Closing delimiter.
      /x
      result = contents.gsub(regexp_long, '')

#       logger.debug(result)

      ticket_salt   = result.scan(/const TicketSalt(.*)=(.*)"(?<ticketsalt>.+\S)"/).flatten
      host_ticket   = nil

      if( ticket_salt.to_s != '' )
        logger.debug(format(' ticket Salt : %s', ticket_salt))
      else
        o      = [('a'..'z'), ('A'..'Z'), (0..9)].map(&:to_a).flatten
        string = (0...50).map { o[rand(o.length)] }.join

        ticket_salt = Digest::SHA256.hexdigest(string)

        File.write(file_name, text.gsub(/const TicketSalt = ""/, "const TicketSalt = \"#{ticket_salt}\""))
      end

      commands = []
      commands << format('icinga2 pki ticket --cn %s --salt %s', host, ticket_salt)

      commands.each_with_index do |c, _index|
        result      = exec_command(cmd: c)

        exit_code    = result.dig(:code)
        exit_message = result.dig(:message)

        if exit_code != true
          logger.error(format('command \'%s\'', c))
          logger.error(format('returned with exit-code %d', exit_code))
          logger.error(exit_message)

          abort 'FAILED !!!'
        end

        host_ticket = exit_message
#         logger.debug(host_ticket)
      end

      timestamp = Time.now

      {
        status: 200,
        master_name: server_name,
        master_ip: server_ip,
        ticket: host_ticket,
        timestamp: timestamp.to_i
      }
    end

    # check the certificate Data
    #
    # @param [Hash, #read] params
    # @option params [String] :host
    # @option params [Hash] :request
    #
    # @example
    #    check_certificate( host: 'icinga2-satellite', request: { 'HTTP_X_CHECKSUM' => '000000000000000000000000000000000000' } )
    #
    # @return [Hash, #read] for an error:
    #  * :status [Integer] 404 or 500
    #  * :message [String] Error Message
    #
    # @return [Hash, #read] for succesfuly:
    #  * :status [Integer] 200
    #  * :file_name [String] Filename
    #  * :path [String]
    #
    def check_certificate( params )

      host         = params.dig(:host)
      checksum     = params.dig(:request, 'HTTP_X_CHECKSUM')
      api_user     = params.dig(:request, 'HTTP_X_API_USER')
      api_password = params.dig(:request, 'HTTP_X_API_PASSWORD')

      return { status: 500, message: 'no valid data to get the certificate' } if( host.nil? || checksum.nil? )

      file = format('%s/%s.tgz', @tmp_directory, host)

      return { status: 404, message: 'file doesn\'t exits' } unless( File.exist?(file) )

      in_memory_data      = find_by_id(checksum)
      generated_timeout   = in_memory_data.dig(:timeout)
      generated_timeout   = File.mtime(file).add_minutes(10) if( generated_timeout.nil? )

      check_timestamp = Time.now

      return { status: 404, message: 'timed out. please ask for an new cert' } if( check_timestamp.to_i > generated_timeout.to_i )

      # add params to create the endpoint not in zones.d
      #
      params[:satellite] = true

      # add API User for this Endpoint
      #
      # add_api_user(params)

      # add Endpoint (and API User)
      # and create a backup of the generated files
      #
      add_endpoint(params)

      # restart service to activate the new certificate
      #
      # reload_icinga_config(params)

      { status: 200, file_name: format('%s.tgz', host), path: @tmp_directory }
    end


    # validate the CA against a checksum
    #
    # @param [Hash, #read] params
    # @option params [String] :checksum
    #
    def validate_certificate( params )

      checksum = params.dig(:checksum)

      return { status: 500, message: 'missing checksum' } if( checksum.nil? )

      pki_base_directory = '/var/lib/icinga2/ca'
      pki_master_ca  = format('%s/ca.crt', pki_base_directory)

      return { status: 500, message: 'no PKI directory found. Please configure first the Icinga2 Master!' } unless( File.exist?(pki_base_directory) )

      if( checksum.be_a_checksum )
        pki_master_ca_checksum = nil
        pki_master_ca_checksum = Digest::MD5.hexdigest(File.read(pki_master_ca)) if( checksum.produced_by(:md5) )
        pki_master_ca_checksum = Digest::SHA256.hexdigest(File.read(pki_master_ca)) if( checksum.produced_by(:sha256) )
        pki_master_ca_checksum = Digest::SHA384.hexdigest(File.read(pki_master_ca)) if( checksum.produced_by(:sha384) )
        pki_master_ca_checksum = Digest::SHA512.hexdigest(File.read(pki_master_ca)) if( checksum.produced_by(:sha512) )

        return { status: 500, message: 'wrong checksum type. only md5, sha256, sha384 and sha512 is supported' } if( pki_master_ca_checksum.nil? )
        return { status: 404, message: 'checksum not match.' } if( checksum != pki_master_ca_checksum )
        return { status: 200 }
      end

      { status: 500, message: 'checksum isn\'t a checksum' }
    end


    # sign a icinga2 satellite certificate with the new 2.8 pki feature
    #
    # @param [Hash, #read] params
    # @option params [String] :host
    # @option params [Hash] :request
    #
    # @example
    #    sign_certificate( host: 'icinga2-satellite', request: { 'HTTP_X_API_USER => 'admin', HTTP_X_API_PASSWORD' => 'admin' } } )
    #
    # @return [Hash, #read] for an error:
    #  * :status [Integer] 404 or 500
    #  * :message [String] Error Message
    #
    # @return [Hash, #read] for succesfuly:
    #  * :status [Integer] 200
    #  * :file_name [String] Filename
    #  * :path [String]
    #
    def sign_certificate( params )

      host         = params.dig(:host)
      api_user     = params.dig(:request, 'HTTP_X_API_USER')
      api_password = params.dig(:request, 'HTTP_X_API_PASSWORD')

      return { status: 500, message: 'no hostname' } if( host.nil? )
      return { status: 500, message: 'missing API Credentials - API_USER' } if( api_user.nil?)
      return { status: 500, message: 'missing API Credentials - API_PASSWORD' } if( api_password.nil? )

      password = read_api_credentials( api_user: api_user )

      return { status: 500, message: 'wrong API Credentials' } if( password.nil? || api_password != password )
      return { status: 500, message: 'wrong Icinga2 Version' } if( @icinga_version != '2.8' )

      # /etc/icinga2 # icinga2 ca list | grep icinga2-satellite-1.matrix.lan | sort -k2
      # e39c0b4bab4d0d9d5f97f0f54da875f0a60273b4fa3d3ef5d9be0d379e7a058b | Jan 10 04:27:38 2018 GMT | *      | CN = icinga2-satellite-1.matrix.lan
      # 5520324447b124a26107ded6d5e5b37d73e2cf2074bd2b5e9d8b860939f490df | Jan 10 04:51:38 2018 GMT |        | CN = icinga2-satellite-1.matrix.lan
      # 6775ea210c7559cf58093dbb151de1aaa3635950f696165eb4beca28487d193c | Jan 10 05:03:36 2018 GMT |        | CN = icinga2-satellite-1.matrix.lan

      commands = []
      commands << format('icinga2 ca list | grep %s | sort -k2 | tail -1', host) # sort by date

      commands.each_with_index do |c, index|

        result       = exec_command(cmd: c)
        exit_code    = result.dig(:code)
        exit_message = result.dig(:message)

        logger.debug( "icinga2 ca list: #{exit_message}" )
        logger.debug( "exit code: #{exit_code} (#{exit_code.class.to_s})" )

        return { status: 500, message: 'error to retrive the list of certificates with signing requests' } if( exit_code == false )

        regex = /^(?<ticket>.+\S) \|(.*)\|(.*)\| CN = (?<cn>.+\S)$/
        parts = exit_message.match(regex) if(exit_message.is_a?(String))

        logger.debug( "parts: #{parts} (#{parts.class.to_s})" )

        if( parts )
          ticket = parts['ticket'].to_s.strip
          cn = parts['cn'].to_s.strip

          result       = exec_command(cmd: format('icinga2 ca sign %s',ticket))
          exit_code    = result.dig(:code)
          exit_message = result.dig(:message)

          logger.debug(exit_code)
          logger.debug(exit_message)

          message = exit_message.gsub('information/cli: ','')

          logger.info(message)

          # create the endpoint and the reference zone
          # the endpoint are only after an reload available!
          #
          add_endpoint(params)

          # logger.debug( format('set reload flag after creating the endpoint (%s)',host) )

          # set an reload flag
          #
          # @cache.set( 'reload' , expires_in: 120 ) { MiniCache::Data.new( params ) }

          # reload the icinga configuration
          #
          #status = reload_icinga_config(params)
          #logger.debug(status)

          return { status: 200, message: message }

        else
          logger.error(format('i can\'t find a Ticket for host \'%s\'',host))
          logger.error( parts )

          return { status: 404, message: format('i can\'t find a Ticket for host \'%s\'',host) }
        end
      end

      { status: 204 }
    end
  end
end
