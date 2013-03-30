class RemoteFileManager
  attr_reader :path, :relpath

  def initialize(path)
    @path = abspath
    @path += "/" + relpath if not relpath.nil?
    @relpath = relpath
  end

  def distribute
    Danbooru.config.other_server_hosts.each do |hostname|
      Net::SFTP.start(hostname, Danbooru.config.remote_server_login) do |ftp|
        ftp.upload!(path, path)
      end
    end
    if not relpath.nil? and Danbooru.config.image_store == :amazon_s3
      AWS::S3::Base.establish_connection!(
        :access_key_id => Danbooru.config.amazon_s3_access_key_id, 
        :secret_access_key => Danbooru.config.amazon_s3_secret_access_key
      )

      if File.exists?(path)
        base64_md5 = Base64.encode64(Digest::MD5.digest(File.read(path)))
        AWS::S3::S3Object.store(relpath, open(path, "rb"), Danbooru.config.amazon_s3_bucket_name, "Content-MD5" => base64_md5)
        # We can now delete the old file (since we aren't storing local)
        FileUtils.rm_f(path)
      end
    end
  end

  def delete
    Danbooru.config.other_server_hosts.each do |hostname|
      Net::SFTP.start(hostname, Danbooru.config.remote_server_login) do |ftp|
        ftp.remove(path)
      end
    end
    if not relpath.nil? and Danbooru.config.image_store == :amazon_s3
      AWS::S3::Base.establish_connection!(
        :access_key_id => Danbooru.config.amazon_s3_access_key_id, 
        :secret_access_key => Danbooru.config.amazon_s3_secret_access_key
      )

      AWS::S3::S3Object.delete(relpath, Danbooru.config.amazon_s3_bucket_name)
    end
  end
end
