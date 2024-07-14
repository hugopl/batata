#!/bin/env -S crystal i
#
# This is a utility used to automatically fill a flatpack file with the
# project dependencies.
#
# Pass the flatpack file and it will output the same file with the crystal
# dependencies injected. See flatpak Makefile target.

require "yaml"

class ShardLockInfo
  include YAML::Serializable

  property git : String
  property version : String
end

class ShardLock
  include YAML::Serializable

  property version : String
  property shards : Hash(String, ShardLockInfo)
end

def find_project_sources(flat_file : YAML::Any) : Array(YAML::Any)
  command = flat_file["command"]?
  abort("command entry not found in flatpack definition.") if command.nil?

  command_module = flat_file["modules"].as_a.find { |entry| entry["name"] == command }
  abort("#{command} module not found in flatpack definition.") if command_module.nil?

  command_module["sources"].as_a
end

def append_shards_to_sources(sources)
  shard_lock = ShardLock.from_yaml(File.read("shard.lock"))
  shard_lock.shards.each do |name, info|
    hash = Hash(YAML::Any, YAML::Any).new
    hash[YAML::Any.new("type")] = YAML::Any.new("git")
    hash[YAML::Any.new("url")] = YAML::Any.new("#{info.git}")

    if info.version =~ /git\.commit\.([a-f0-9]{40})/
      hash[YAML::Any.new("commit")] = YAML::Any.new($1)
    else
      hash[YAML::Any.new("tag")] = YAML::Any.new("v#{info.version}")
    end

    hash[YAML::Any.new("dest")] = YAML::Any.new("lib/#{name}")
    sources << YAML::Any.new(hash)
  end
end

abort("Pass the flatpack definition file as argument.") if ARGV.empty?

flat_file = YAML.parse(File.read(ARGV[0]))
sources = find_project_sources(flat_file)
append_shards_to_sources(sources)

flat_file.to_yaml(STDOUT)
