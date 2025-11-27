require 'sidekiq'

module Application
  # Background job class for sending archives via email
  class ArchiveSender
    include Sidekiq::Worker

    # Perform the email sending job
    # @param archive_path [String] Path to the archive file
    # @param recipient_email [String] Email address to send the archive to
    def perform(archive_path, recipient_email)
      return unless File.exist?(archive_path)

      begin
        LoggerManager.log_processed_file(archive_path, 'STARTED', 'Starting email send process')

        # Configure Pony with SMTP settings (should be moved to config)
        Pony.mail(
          to: recipient_email,
          subject: 'Web Crawler Results Archive',
          body: "Please find attached the results archive from the web crawler execution.\n\nGenerated at: #{Time.now}",
          attachments: { File.basename(archive_path) => File.read(archive_path) },
          via: :smtp,
          via_options: {
            address: 'smtp.gmail.com', # Should be configurable
            port: '587',
            enable_starttls_auto: true,
            user_name: ENV.fetch('SMTP_USERNAME', nil), # Should be in config
            password: ENV.fetch('SMTP_PASSWORD', nil), # Should be in config
            authentication: :plain
          }
        )

        LoggerManager.log_processed_file(archive_path, 'SUCCESS', "Archive sent to #{recipient_email}")
        puts "Archive sent successfully to #{recipient_email}"
      rescue StandardError => e
        error_message = "Failed to send archive via email: #{e.message}"
        LoggerManager.log_error(error_message, e, 'ArchiveSender.perform')
        puts error_message
      end
    end
  end
end
