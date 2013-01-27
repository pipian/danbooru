require 'fileutils'

FactoryGirl.define do
  factory(:upload) do
    rating "s"
    uploader :factory => :user, :level => 20
    uploader_ip_addr "127.0.0.1"
    tag_string "special"
    status "pending"
    server Socket.gethostname
    
    factory(:source_upload) do
      source "http://www.google.com/intl/en_ALL/images/logo.gif"
    end

    factory(:jpg_upload) do
      content_type "image/jpeg"
      file_path do
        FileUtils.cp("#{Rails.root}/test/files/test.jpg", "#{Rails.root}/tmp")
        "#{Rails.root}/tmp/test.jpg"
      end
    end

    factory(:large_jpg_upload) do
      file_ext "jpg"
      content_type "image/jpeg"
      file_path do
        FileUtils.cp("#{Rails.root}/test/files/test-large.jpg", "#{Rails.root}/tmp")
        "#{Rails.root}/tmp/test-large.jpg"
      end
    end

    factory(:png_upload) do
      file_path do
        FileUtils.cp("#{Rails.root}/test/files/test.png", "#{Rails.root}/tmp")
        "#{Rails.root}/tmp/test.png"
      end
    end

    factory(:gif_upload) do
      file_path do
        FileUtils.cp("#{Rails.root}/test/files/test.gif", "#{Rails.root}/tmp")
        "#{Rails.root}/tmp/test.gif"
      end
    end
  end
end

