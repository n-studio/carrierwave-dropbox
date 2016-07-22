require 'test_helper'

class FileUploadTest < Minitest::Test
  def teardown
    Image.all.each do |image|
      image.destroy
    end
  end

  def test_uploading_a_simple_file
    original_count = Image.count

    post "/image/upload", attachment: file_upload('rails.png')

    assert last_response.ok?
    assert_equal 1, (Image.count - original_count)
    last_image = Image.last
    refute last_image.attachment.url.empty?

    # get data on upload
    assert_equal '13036', last_image.file_size
    assert_equal 'image/png', last_image.content_type

    # get data on download
    assert_equal 'rails.png', last_image.attachment.file.original_filename
    assert_equal 'rails.png', last_image.attachment.file.filename
    assert_equal 'rails', last_image.attachment.file.basename
    assert_equal 'png', last_image.attachment.file.extension
    # TODO: assert_equal 13036, last_image.attachment.file.size
    assert_equal "test/images/#{last_image.id}/rails.png", last_image.attachment.file.path
    assert_equal false, last_image.attachment.file.is_path?
    assert_equal false, last_image.attachment.file.empty?
    assert_equal true, last_image.attachment.file.exists?
    # TODO: assert_equal false, last_image.attachment.file.read.nil?
    # TODO: last_image.attachment.file.move_to!(new_path)
    # TODO: last_image.attachment.file.copy_to(new_path, permissions=nil, directory_permissions=nil)
    # TODO: last_image.attachment.file.copy!(new_path)
    # TODO: assert_equal ::File, last_image.attachment.file.to_file.class
    assert_equal 'image/png', last_image.attachment.file.content_type
    # TODO: last_image.attachment.file.attributes
  end

  def test_upload_image_editing
    post "/image/upload", attachment: file_upload('ruby.png')
    image = Image.last

    assert_match 'ruby.png', image.attachment.url

    put "/image/edit/#{image.id}", attachment: file_upload('rails.png')

    assert last_response.ok?
    last_image = Image.last
    assert_match 'rails.png', last_image.attachment.url
  end

  # def test_delete_image
  #   post "/image/upload", attachment: file_upload('ruby.png')
  #   image = Image.last

  #   assert_match 'ruby.png', image.attachment.url

  #   get image.attachment.url
  #   assert last_response.ok?, "Couldn't reach #{last_request.url}"

  #   delete "/image/#{image.id}"

  #   get image.attachment.url
  #   assert !last_response.ok?
  # end
end
