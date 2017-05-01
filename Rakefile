require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)
task default: [:spec, :performance_test]

desc 'Check performance'
task :performance_test do
  ruby 'scripts/command_performance.rb'
end
