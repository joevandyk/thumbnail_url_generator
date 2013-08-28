require 'active_support/core_ext'

# Needs a lot of cleanup.
module Rooster
  module ThumbnailGenerator
    # Given a format string and the original width and height,
    # return a string like "300x200" representing the image width and height.
    def self.resize_to_string format_string, original_width, original_height
      resize(format_string, original_width, original_height).join('x')
    end

    # Given a format string and the original width and height,
    # return an array representing the thumbnails's width and height.
    # Client code might not need to access this, probably consider
    # this private.
    def self.resize format_string, original_width, original_height
      width_str, height_str = format_string.split('x')

      # Some of our images don't have width and height set. :(
      return [nil, nil] if original_width.blank? or original_height.blank?

      width  = (width_str  and width_str.length > 0)  ?  width_str.to_f : nil
      height = (height_str and height_str.length > 0) ? height_str.to_f : nil

      modifier = case format_string[-1]
                 when '!' then :exact
                 when '<' then :resize_width # Not yet supported
                 end

      if modifier == :exact
        return [width, height]
      end

      aspect_ratio = original_width.to_f / original_height

      (if width.nil?
       resize_factor = height / original_height
       [original_width * resize_factor, height]
      elsif height.nil?
        resize_factor = width / original_width
        [width, original_height * resize_factor]
      else
        resize_factor = [width / original_width, height / original_height].min
        [original_width * resize_factor, original_height * resize_factor]
      end).map(&:round)
    end


    # Given an image object and a size, create an image tag
    # for the thumbnail. options are passed to Rails's image tag.
    def self.image_tag media, size, options={}
      if media.blank?
        return ""
      else
        if size.kind_of? Symbol
          # This shouldn't be needed on the new site.
          # Keeping it until the old site is completely removed.
          size = Media.lookup_size(size)
        end
        options[:width], options[:height] = resize(size, media.width, media.height)
        ActionController::Base.helpers.image_tag(image_url(media, size), options)
      end
    end

    # Generates the image size part of a thumbnail URL.
    # Like: w_230,h_230 or c_fill,w_230,h_230
    def self.cloudinary_format size, media
      return "/original/" if size.blank?

      format_string = []
      if size.include?('!')
        format_string << "c_fill"
      end

      size = size.gsub(/[^\dx]/, '') # Remove everything that's not a digit or an 'x'
      width,height = size.split('x')
      if width.present?
        format_string << "w_#{width}"
      end
      if height.present?
        format_string << "h_#{height}"
      end

      "/" + format_string.join(',') + "/"
    end

    def self.cloudinary_base_url media
      if Rails.env.production?
        "https://d3vjvsn2tynjug.cloudfront.net/v2"
      else
        "https://dev-images.tanga.com/v2"
      end
    end

    def self.s3_image_url media, size
      url = cloudinary_base_url(media)
      url << cloudinary_format(size, media)

      if media.class.to_s == 'Media' or media.class.to_s == "Hash"
        url << CGI.escape(media.url)
      else
        if Rails.application.assets.find_asset(media)
          # In the assets/images folder, asset pipeline has done stuff to it.
          path = path_to_image(media)

          # I'm not sure why, but path_to_image sometimes doesn't return the complete
          # URL to the image. Seems to only happen on Tanga in production.
          if path !~ /^https/
            path = Site.current.config.asset_host + path
          end
          url << CGI.escape(path)
        else
          # In the public folder or an absolute URL.
          url << CGI.escape(root_url) if media !~ /^https?:\/\//
            url << CGI.escape(media)
        end
      end
    end

    # Takes a string (path to an image), or a Media object.
    # size is an imagemagick size ("30x30!" or something)
    def self.image_url object, size=nil
      return "" if object.blank?
      return s3_image_url(object, size)
    end

    def self.root_url
      Rails.application.routes.url_helpers.root_url(:only_path => true)
    end
  end
end