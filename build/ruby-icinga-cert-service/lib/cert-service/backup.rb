
module IcingaCertService
  #
  #
  #
  module Backup

    # create Backup of generated files
    #
    def create_backup

      source_directory = '/etc/icinga2'
      backup_directory = '/var/lib/icinga2/backup'

      FileUtils.mkpath(backup_directory) unless File.exist?(backup_directory)

      white_list = %w(zones.d zones.conf conf.d/api-users.conf)

      white_list.each do |p|

        source_file = format( '%s/%s', source_directory, p )

        destination_directory = File.dirname( source_file )
        destination_directory.gsub!( source_directory, backup_directory )

        FileUtils.mkpath(destination_directory) unless File.exist?(destination_directory)

        if( File.directory?(source_file) )
          FileUtils.cp_r(source_file, "#{backup_directory}/", :noop => false, :verbose => false )
        else
          FileUtils.cp_r(source_file, "#{backup_directory}/#{p}", :noop => false, :verbose => false )
        end
      end

    end
  end
end
