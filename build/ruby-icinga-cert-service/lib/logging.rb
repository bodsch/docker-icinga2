
require 'logger'

# -------------------------------------------------------------------------------------------------

module Logging

  def logger
    @logger ||= Logging.logger_for( self.class.name )
  end

  # Use a hash class-ivar to cache a unique Logger per class:
  @loggers = {}

  class << self

    def logger_for( classname )
      @loggers[classname] ||= configure_logger_for( classname )
    end

    def configure_logger_for( classname )

      $stdout.sync = true
      logger                 = Logger.new($stdout)
#      logger.progname        = classname
      logger.level           = Logger::INFO
      logger.datetime_format = '%Y-%m-%d %H:%M:%S::%3N'
      logger.formatter       = proc do |severity, datetime, progname, msg|
        "[#{datetime.strftime( logger.datetime_format )}] #{severity.ljust(5)} : #{progname} #{msg}\n"
      end

      logger
    end
  end
end

# -------------------------------------------------------------------------------------------------
