# The parameters we stick in Resources.
class Puppet::Parser::Resource::Param
  include Puppet::Util
  include Puppet::Util::Errors

  attr_accessor :name, :value, :source, :add, :file, :line

  def initialize(hash)
    unless hash[:name]
      raise ArgumentError, "'name' is a required argument for #{self.class}"
    end

    @name = hash[:name].intern
    @value = hash[:value]
    @source = hash[:source]
    @line = hash[:line]
    @file = hash[:file]
    @add = hash[:add]
  end

  def line_to_i
    line ? Integer(line) : nil
  end

  def to_s
    "#{self.name} => #{self.value}"
  end
end
