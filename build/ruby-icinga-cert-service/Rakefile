
require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'bundler/gem_tasks'
require 'rubocop/rake_task'
require 'rake/testtask'

# Default directory to look in is `/specs`
# Run with `rake spec`
RSpec::Core::RakeTask.new(:spec) do |task|
  task.rspec_opts = ['--color']
end

desc 'Run all style checks'
task :style => ['style:ruby']

desc 'Run all regular tasks'
task :default => :spec

desc 'Run all tests'
task :test => ['test']

namespace :style do
  desc 'Run Ruby style checks'
  RuboCop::RakeTask.new(:ruby) do |task|
    task.patterns = ['**/*.rb']
    # don't abort rake on failure
    task.fail_on_error = false
  end
end


Rake::TestTask.new("test:all") do |t|
  t.libs = ["lib", "spec"]
  t.warning = true
  t.test_files = FileList['spec/**/*_spec.rb']
end
