# Uploads ActiveStorage blobs to Cloudflare R2 and returns a persistent CDN URL.
# Used by LINE send service because ActiveStorage disk URLs expire in 5 minutes,
# but LINE fetches images asynchronously (after expiry) -> 404 -> broken image.
#
# Config via ENV:
#   R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY, R2_ENDPOINT, R2_BUCKET, R2_PUBLIC_URL
class R2UploadService
  def self.configured?
    ENV['R2_BUCKET'].present? && ENV['R2_ACCESS_KEY_ID'].present?
  end

  def self.upload_blob(blob, prefix: 'chatwoot')
    return nil unless configured?

    # Sanitize filename: replace spaces/special chars with underscores to ensure
    # the CDN URL is a valid HTTPS URL (LINE API rejects URLs with unencoded spaces).
    safe_name = blob.filename.to_s.gsub(/[^a-zA-Z0-9._-]/, '_')
    key = "#{prefix}/public/#{blob.key}_#{safe_name}"
    client.put_object(
      bucket: ENV.fetch('R2_BUCKET'),
      key: key,
      body: blob.download,
      content_type: blob.content_type,
      cache_control: 'public, max-age=31536000, immutable'
    )

    "#{ENV.fetch('R2_PUBLIC_URL')}/#{key}"
  rescue Aws::S3::Errors::ServiceError => e
    Rails.logger.error "[R2Upload] Failed to upload blob #{blob.key}: #{e.message}"
    nil
  end

  def self.client
    @client ||= Aws::S3::Client.new(
      access_key_id: ENV.fetch('R2_ACCESS_KEY_ID'),
      secret_access_key: ENV.fetch('R2_SECRET_ACCESS_KEY'),
      endpoint: ENV.fetch('R2_ENDPOINT'),
      region: 'auto',
      force_path_style: true
    )
  end
end
