
require 'open3'

module IcingaCertService

  module Executor

    # execute system commands with a Open3.popen2() call
    #
    # @param [Hash, #read] params
    # @option params [String] :cmd
    #
    # @return [Hash, #read]
    #  * :exit [Integer] Exit-Code
    #  * :message [String] Message
    def exec_command( params )

      cmd = params.dig(:cmd)

      return { code: 1, message: 'no command found' } if( cmd.nil? )

      result = {}

      Open3.popen2( cmd ) do |_stdin, stdout_err, wait_thr|
        return_value = wait_thr.value
        result = { code: return_value.success?, message: stdout_err.gets }
      end

      result
    end
  end
end
