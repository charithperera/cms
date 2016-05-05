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

  def session
    last_request.env["rack.session"]
  end

  def admin_session
    {"rack.session" => { username: "admin"} }
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
    # assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    # get last_response["Location"]

    assert_equal "nofile.txt does not exist!", session[:message]
    # assert_includes last_response.body, "nofile.txt does not exist"  
  end

  def test_edit
    create_document("about.md")
    get "/about.md/edit", {}, admin_session
    assert_equal 200, last_response.status
    assert_includes last_response.body, "textarea"
    assert_includes last_response.body, "submit"
  end

  def test_edit_signed_out
    create_document("about.md")
    get "/about.md/edit"
    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that", session[:message]

  end

  def test_save
    post "/changes.txt/save", { input_content: "some new content" }, admin_session
    assert_equal 302, last_response.status
    # get last_response["location"]
    # assert_includes last_response.body, "changes.txt has been updated"
    assert_equal "changes.txt has been updated successfully.", session[:message]

    get "/changes.txt"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "new content"
  end

  def test_save_signed_out
    post "/changes.txt/save", { input_content: "some new content" }
    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that", session[:message]    
  end

  def test_create_form
    get "/new", {}, admin_session
    assert_equal 200, last_response.status
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_create_form_signed_out
    get "/new"

    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that", session[:message]  
  end

  def test_create
    post "/create", { new_document: "new_file.txt" }, admin_session
    assert_equal 302, last_response.status

    # get last_response["location"]
    # assert_includes last_response.body, "new_file.txt created"
    assert_equal "new_file.txt created", session[:message]
  

    get "/"
    assert_includes last_response.body, "new_file.txt"
  end

  def test_create_signed_out
    post "/create", { new_document: "new_file.txt" }
    assert_equal 302, last_response.status    
    assert_equal "You must be signed in to do that", session[:message]      
  end

  def test_create_without_filename
    post "/create", { new_document: "" }, admin_session
    assert_equal 422, last_response.status
    assert_includes last_response.body, "No file name provided. Not created."
  end

  def test_create_invalid_filetype
    post "/create", { new_document: "bad_file.no" }, admin_session
    assert_equal 422, last_response.status
    assert_includes last_response.body, "Only txt and md files allowed"
  end

  def test_delete
    create_document("delete_this.txt")

    post "/delete_this.txt/delete", {}, admin_session
    assert_equal 302, last_response.status

    # get last_response["location"]
    # assert_includes last_response.body, "delete_this.txt deleted!"
    assert_equal "delete_this.txt deleted!", session[:message]    
    
    # get last_response["location"]

    get "/"
    refute_includes last_response.body, %q(href="/delete_this.txt")
  end

  def test_delete_signed_out
    create_document("delete_this.txt")
    post "/delete_this.txt/delete", {}
    assert_equal 302, last_response.status    
    assert_equal "You must be signed in to do that", session[:message]     
  end

  def test_signin_page
    get "/users/sign_in"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "Username"
    assert_includes last_response.body, "Password"
  end

  def test_signin_success
    post "/users/sign_in", username: "admin", password: "secret"
    assert_equal 302, last_response.status
    assert_equal "admin", session[:username]
    assert_equal "Welcome!", session[:message]

    get last_response["location"]
    assert_includes last_response.body, "Signed in as admin"    
  end

  def test_signin_fail
    post "/users/sign_in", username: "bad", password: "login"
    assert_equal 422, last_response.status
    assert_equal nil, session[:username]
    assert_includes last_response.body, "Authentication failed"

  end

  def test_signout
    # post "/users/sign_in", username: "admin", password: "secret"
    # get last_response["location"]
    # assert_includes last_response.body, "Welcome" 

    get "/", {}, admin_session
    assert_includes last_response.body, "Signed in as admin"

    post "/users/sign_out"
    get last_response["location"]
    assert_equal nil, session[:username]
    assert_includes last_response.body, "Signed out successfully"
    assert_includes last_response.body, "Sign In"
  end

end
