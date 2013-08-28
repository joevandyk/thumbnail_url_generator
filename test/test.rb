require 'bundler/setup'
require_relative '../thumbnail_url_generator'

require 'test/unit'

class TestThis < Test::Unit::TestCase
  CASES = {
    ["300x300", 300, 300]  => [300, 300],
    ["200x200", 300, 300]  => [200, 200],
    ["200x200!", 400, 300] => [200, 200],
    ["100x100", 800, 600]  => [100, 75],
    ["100x100", 600, 800]  => [75,  100],
    ["100x100", 50, 60]    => [83, 100],
    ["100x100!", 50, 60]   => [100, 100],
    ["200x100", 200, 200]  => [100, 100],
    ["100x200", 200, 200]  => [100, 100],
    ["230x230>", 750, 750]  => [230, 230],
    ["200x", 300, 600]  => [200, 400],
    ["200x", 600, 300]  => [200, 100],
    ["x200", 300, 600]  => [100, 200],
    ["x200", 600, 300]  => [400, 200],
  }

  CASES.each do |test, answer|
    define_method "test #{test} => #{answer}" do
      assert_equal answer, Rooster::ThumbnailGenerator.resize(*test)
    end
  end
end
