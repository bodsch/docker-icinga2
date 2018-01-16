
module IcingaCertService

  # small in-memory Cache
  #
  module InMemoryDataCache
    # create a new Instance
    def initialize
      @storage = {}
    end

    # save data
    #
    # @param [String, #read] id
    # @param [misc, #read] data
    #
    def save(id, data)
      @storage ||= {}
      @storage[id] ||= {}
      @storage[id] = data
    end

    # get data
    #
    # @param [String, #read]
    #
    def find_by_id(id)
      if( !@storage.nil? )
        @storage.dig(id) || {}
      else
        {}
      end
    end

    # get all data
    #
    def entries
      @storage
    end
  end
end
