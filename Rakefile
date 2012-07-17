#!/usr/bin/env rake
require 'bundler/gem_tasks'
require 'bundler/setup'
require 'rspec/core/rake_task'
require 'pry'

desc 'run console'
task :console do
  exec('bundle exec pry -I lib -r mzl')
end

desc 'run specs'
RSpec::Core::RakeTask.new
