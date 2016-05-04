ENV["RACK_ENV"] = "test"

require "minitest/autorun"
require "rack/test"
require "fileutils"

require_relative "../cms"

class CMSTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def setup
    FileUtils.mkdir_p(data_path)
  end

  def teardown
    FileUtils.rm_rf(data_path)
  end

  def create_document(name, content="")
    File.open(File.join(data_path, name), "w") do |file|
      file.write(content)
    end
  end

  def test_index
    create_document("about.md")
    create_document("changes.txt")
    create_document("history.txt")

    get "/"
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]    
    assert_includes last_response.body, "history.txt"
    assert_includes last_response.body, "changes.txt"
    assert_includes last_response.body, "about.md"
  end

  def test_viewfile
    create_document("history.txt", "1978")

    get "/history.txt"
    assert_equal 200, last_response.status
    assert_equal "text/plain", last_response["Content-Type"]
    assert_includes last_response.body, "1978"
  end

  def test_markdown
    create_document("about.md", "#Heading")
    get "/about.md"
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "<h1>Heading</h1>"    
  end

  def test_nofile
    get "/nofile.txt"
    assert_equal 302, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    get last_response["Location"]
    assert_includes last_response.body, "nofile.txt does not exist"  
  end

  def test_edit
    create_document("about.md")
    get "/about.md/edit"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "textarea"
    assert_includes last_response.body, "submit"
  end

  def test_save
    #save original content
    post "/changes.txt/save", input_content: "some new content"
    assert_equal 302, last_response.status
    get last_response["location"]
    assert_includes last_response.body, "changes.txt has been updated"

    get "/changes.txt"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "new content"
  end
end