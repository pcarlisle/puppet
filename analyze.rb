#!/usr/bin/env ruby

require 'oj'
require 'set'
require 'pp'

class Searcher
  def initialize
    @seen_addrs = Set.new
    @trail = []
    @queue = []
    @back_references = {}
  end

  def read_dump(file)
    File.open(file) do |f|
      f.each_line do |line|
        object = Oj.load line
        if object['references']
          object['references'].each do |ref|
            @back_references[ref] = [] if @back_references[ref].nil?
            @back_references[ref] << object
          end
        end
      end
    end
  end

  def mark_seen(obj)
    @seen_addrs << obj['address']
  end

  def enqueue(o)
    @queue.push o
  end

  def seen?(a)
    @seen_addrs.include?(a)
  end

  def find_referents(obj_address)
    puts "Finding #{obj_address}"
    @queue = []
    @queue.concat @back_references[obj_address]

    while !@queue.empty? do
      obj = @queue.shift
      # add ref to the list of things referencing our starting ref
      @trail << obj
      mark_seen(obj)
      # queue up everything referencing this object to be searched on the next pass
      if obj['address']
        if refs = @back_references[obj['address']]
          refs.each do |referred_obj|
            enqueue(referred_obj) unless seen?(referred_obj['address'])
          end
        end
      end
    end
    @trail
  end
end

searcher = Searcher.new

searcher.read_dump(ARGV[0])
searcher.find_referents(ARGV[1])
