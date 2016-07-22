require 'sinatra'

require 'active_record'
require 'carrierwave'
require 'carrierwave/dropbox'
require 'carrierwave/orm/activerecord'

ActiveRecord::Base.raise_in_transactional_callbacks = true

ActiveRecord::Base.establish_connection(
  adapter:  'sqlite3',
  database: ':memory:'
)

ActiveRecord::Schema.define do
  create_table :images do |t|
    t.string :attachment
    t.string :content_type
    t.string :file_size
  end
end

CarrierWave.configure do |config|
  config.dropbox_app_key             = ENV["APP_KEY"]
  config.dropbox_app_secret          = ENV["APP_SECRET"]
  config.dropbox_access_token        = ENV["ACCESS_TOKEN"]
  config.dropbox_access_token_secret = ENV["ACCESS_TOKEN_SECRET"]
  config.dropbox_user_id             = ENV["USER_ID"]
  config.dropbox_access_type         = ENV["APP_TYPE"]
end

class ImageUploader < CarrierWave::Uploader::Base
  storage :dropbox

  def store_dir
    "test/images/#{model.id}"
  end

  process :save_meta_data

  def save_meta_data
    model.content_type = file.content_type
    model.file_size = file.size
  end
end

class Image < ActiveRecord::Base
  mount_uploader :attachment, ImageUploader
end

class DummyApplication < Sinatra::Application
  post '/image/upload' do
    Image.create!(attachment: params[:attachment])
  end

  put '/image/edit/:id' do |id|
    Image.find(id).update(attachment: params[:attachment])
  end

  delete '/image/:id' do |id|
    Image.find(id).destroy
  end
end
