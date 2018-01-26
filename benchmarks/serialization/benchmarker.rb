require 'puppet'
require 'multi_json'

class Benchmarker
  def initialize(target, size)
    @size = size
    @direction = ENV['SER_DIRECTION'] == 'generate' ? :generate : :parse
    @format = ENV['SER_FORMAT'] == 'pson' ? :pson : :json

    MultiJson.use('jr_jackson')
    puts "Benchmarker #{@direction} #{@format} #{MultiJson.adapter}"
  end

  def setup
  end

  def generate
    path = File.expand_path(File.join(__FILE__, '../catalog.json'))
    puts "Using catalog #{path}"

    @data = File.read(path)
    @catalog = MultiJson.load(@data)
  end

  def run(args=nil)
    0.upto(@size) do |i|
      # This parses a catalog from JSON data, which is a combination of parsing
      # the data into a JSON hash, and the parsing the hash into a Catalog. It's
      # interesting to see just how slow that latter process is:
      #
      #   Puppet::Resource::Catalog.convert_from(:json, @data)
      #
      # However, for this benchmark, we're just testing how long JSON vs PSON
      # parsing and generation are, where we default to parsing JSON.
      #
      if @direction == :generate
        if @format == :pson
          PSON.dump(@catalog)
        else
          MultiJson.dump(@catalog)
        end
      else
        if @format == :pson
          PSON.parse(@data)
        else
          MultiJson.load(@data)
        end
      end
    end
  end
end
