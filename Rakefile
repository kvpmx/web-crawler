require 'rake'

# Default task - shows available tasks
task :default do
  puts 'Web Crawler Application Tasks:'
  puts '  rake run    - Run the main application'
  puts '  rake help   - Show this help message'
end

# Task to run the main application
desc 'Run the web crawler application'
task :run do
  puts 'Starting Web Crawler Application via Rake...'
  begin
    # Execute main.rb directly
    ruby 'main.rb'
  rescue StandardError => e
    puts "Error running application: #{e.message}"
    puts 'Make sure all dependencies are installed with: bundle install'
    exit 1
  end
end

# Help task
desc 'Show available Rake tasks'
task :help do
  Rake::Task.tasks.each do |task|
    printf "%-20<name>s %<comment>s\n", name: task.name, comment: task.comment || ''
  end
end

# Task for installing dependencies
desc 'Install application dependencies'
task :install do
  puts 'Installing dependencies...'
  system('bundle install')
end

# Task for cleaning output files
desc 'Clean output and log files'
task :clean do
  require 'fileutils'

  puts 'Cleaning output files...'
  FileUtils.rm_rf('output/*.csv')
  FileUtils.rm_rf('output/*.json')
  FileUtils.rm_rf('output/*.txt')
  FileUtils.rm_rf('output/yaml/*.yml')
  FileUtils.rm_rf('output/*.zip')

  puts 'Cleaning log files...'
  FileUtils.rm_rf('logs/*.log')

  puts 'Clean completed.'
end

# Task for demonstrating the application functionality
desc 'Demonstrate the application functionality'
task :demo do
  puts 'Demonstrating the application functionality...'
  system('ruby demo.rb')
end
