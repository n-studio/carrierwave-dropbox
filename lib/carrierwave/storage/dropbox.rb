# encoding: utf-8
require 'dropbox_sdk'

module CarrierWave
  module Storage
    class Dropbox < Abstract

      # Stubs we must implement to create and save
      # files (here on Dropbox)

      # Store a single file
      def store!(file)
        f = CarrierWave::Storage::Dropbox::File.new(uploader, config, uploader.store_path, dropbox_client)
        f.store(file)
        f
      end

      # Retrieve a single file
      def retrieve!(file)
        CarrierWave::Storage::Dropbox::File.new(uploader, config, uploader.store_path(file), dropbox_client)
      end

      def dropbox_client
        @dropbox_client ||= begin
          session = DropboxSession.new(config[:app_key], config[:app_secret])
          session.set_access_token(config[:access_token], config[:access_token_secret])
          DropboxClient.new(session, config[:access_type])
        end
      end

      private

      def config
        @config ||= {}

        @config[:app_key] ||= uploader.dropbox_app_key
        @config[:app_secret] ||= uploader.dropbox_app_secret
        @config[:access_token] ||= uploader.dropbox_access_token
        @config[:access_token_secret] ||= uploader.dropbox_access_token_secret
        @config[:access_type] ||= uploader.dropbox_access_type || "dropbox"
        @config[:user_id] ||= uploader.dropbox_user_id

        @config
      end

      class File
        include CarrierWave::Utilities::Uri
        attr_reader :path
        attr_accessor :file, :url

        class << self
          attr_writer :sanitize_regexp

          def sanitize_regexp
            @sanitize_regexp ||= /[^[:word:]\.\-\+]/
          end
        end

        def initialize(uploader, config, path, client)
          @uploader, @config, @path, @client = uploader, config, path, client
          @original_filename = ::File.basename(path)
        end

        def store(file)
          location = (@config[:access_type] == "dropbox") ? "/#{@uploader.store_path}" : @uploader.store_path
          file_hash = @client.put_file(location, file.to_file)
          @file = file.to_file
          true
        end

        def url
          @url ||= @client.media(@path)["url"]
        end

        ##
        # Returns the filename as is, without sanitizing it.
        #
        # === Returns
        #
        # [String] the unsanitized filename
        #
        def original_filename
          @original_filename
        end

        ##
        # Returns the filename, sanitized to strip out any evil characters.
        #
        # === Returns
        #
        # [String] the sanitized filename
        #
        def filename
          sanitize(original_filename) if original_filename
        end

        alias_method :identifier, :filename

        ##
        # Returns the part of the filename before the extension. So if a file is called 'test.jpeg'
        # this would return 'test'
        #
        # === Returns
        #
        # [String] the first part of the filename
        #
        def basename
          split_extension(filename)[0] if filename
        end

        ##
        # Returns the file extension
        #
        # === Returns
        #
        # [String] the extension
        #
        def extension
          split_extension(filename)[1] if filename
        end

        ##
        # Returns the file's size.
        #
        # === Returns
        #
        # [Integer] the file's size in bytes.
        #
        def size
          file.nil? ? 0 : file.size
        end

        ##
        # Returns the full path to the file. If the file has no path, it will return nil.
        #
        # === Returns
        #
        # [String, nil] the path where the file is located.
        #
        def path
          @path
        end

        ##
        # === Returns
        #
        # [Boolean] whether the file is supplied as a pathname or string.
        #
        def is_path?
          false
        end

        ##
        # === Returns
        #
        # [Boolean] whether the file is valid and has a non-zero size
        #
        def empty?
          self.size.nil? || (self.size.zero? && ! self.exists?)
        end

        ##
        # === Returns
        #
        # [Boolean] Whether the file exists
        #
        def exists?
          @url.present?
        end

        ##
        # Returns the contents of the file.
        #
        # === Returns
        #
        # [String] contents of the file
        #
        def read
          if @content
            @content
          elsif @file
            @file.try(:rewind)
            @content = @file.read
            @file.try(:close) unless @file.try(:closed?)
            @content
          end
        end

        ##
        # Moves the file to the given path
        #
        # === Parameters
        #
        # [new_path (String)] The path where the file should be moved.
        # [permissions (Integer)] permissions to set on the file in its new location.
        # [directory_permissions (Integer)] permissions to set on created directories.
        #
        def move_to(new_path, permissions=nil, directory_permissions=nil, keep_filename=false)
          # TODO
          path = @path
          path = "/#{path}" if @config[:access_type] == "dropbox"
          @client.file_move(path, new_path)
        end
        ##
        # Helper to move file to new path.
        #
        def move!(new_path)
          # TODO
          # move_to(new_path)
        end

        ##
        # Creates a copy of this file and moves it to the given path. Returns the copy.
        #
        # === Parameters
        #
        # [new_path (String)] The path where the file should be copied to.
        # [permissions (Integer)] permissions to set on the copy
        # [directory_permissions (Integer)] permissions to set on created directories.
        #
        # === Returns
        #
        # @return [CarrierWave::SanitizedFile] the location where the file will be stored.
        #
        def copy_to(new_path, permissions=nil, directory_permissions=nil)
          # TODO
          # return if self.empty?
          # path = @path
          # path = "/#{path}" if @config[:access_type] == "dropbox"
          # @client.file_copy(path, new_path)
        end

        ##
        # Helper to create copy of file in new path.
        #
        def copy!(new_path)
          # TODO
          # copy(new_path)
        end

        ##
        # Removes the file.
        #
        def delete
          path = @path
          path = "/#{path}" if @config[:access_type] == "dropbox"
          begin
            @client.file_delete(path)
          rescue DropboxError
          end
        end

        ##
        # Returns a File object, or nil if it does not exist.
        #
        # === Returns
        #
        # [File] a File object representing the SanitizedFile
        #
        def to_file
          return file
        end

        ##
        # Returns the content type of the file.
        #
        # === Returns
        #
        # [String] the content type of the file
        #
        def content_type
          return @content_type if @content_type
          if @file.respond_to?(:content_type) and @file.content_type
            @content_type = @file.content_type.to_s.chomp
          elsif path
            @content_type = ::MIME::Types.type_for(path).first.to_s
          end
        end

        ##
        # Sets the content type of the file.
        #
        # === Returns
        #
        # [String] the content type of the file
        #
        def content_type=(type)
          @content_type = type
        end

        ##
        # Used to sanitize the file name. Public to allow overriding for non-latin characters.
        #
        # === Returns
        #
        # [Regexp] the regexp for sanitizing the file name
        #
        def sanitize_regexp
          CarrierWave::SanitizedFile.sanitize_regexp
        end

        private

        def sanitize(name)
          name = name.tr("\\", "/") # work-around for IE
          name = ::File.basename(name)
          name = name.gsub(sanitize_regexp,"_")
          name = "_#{name}" if name =~ /\A\.+\z/
          name = "unnamed" if name.size == 0
          return name.mb_chars.to_s
        end

        def split_extension(filename)
          # regular expressions to try for identifying extensions
          extension_matchers = [
            /\A(.+)\.(tar\.([glx]?z|bz2))\z/, # matches "something.tar.gz"
            /\A(.+)\.([^\.]+)\z/ # matches "something.jpg"
          ]

          extension_matchers.each do |regexp|
            if filename =~ regexp
              return $1, $2
            end
          end
          return filename, "" # In case we weren't able to split the extension
        end
      end
    end
  end
end
