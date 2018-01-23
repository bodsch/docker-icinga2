
# check if is a checksum
#
class Object

  REGEX = /\A[0-9a-f]{32,128}\z/i
  CHARS = {
    md2: 32,
    md4: 32,
    md5: 32,
    sha1: 40,
    sha224: 56,
    sha256: 64,
    sha384: 96,
    sha512: 128
  }

  def be_a_checksum
    !!(self =~ REGEX)
  end

  def produced_by( name )
    function = name.to_s.downcase.to_sym

    raise ArgumentError, "unknown algorithm given to be_a_checksum.produced_by: #{function}" unless CHARS.include?(function)

    return true if( size == CHARS[function] )
    false
  end
end

# add minutes
#
class Time
  def add_minutes(m)
    self + (60 * m)
  end
end

