require "sinatra"
require "sinatra/reloader"
require "tilt/erubis"
require "redcarpet"
require "pry"
require "yaml"
require "bcrypt"

# root = File.expand_path("..", __FILE__)
@user_signed_in = true

configure do
  enable :sessions
  set :session_secret, 'secret'
end

def data_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
end

def load_cred
  cred_path = if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/users.yml", __FILE__)
  else
    File.expand_path("../users.yml", __FILE__)
  end  
  YAML.load_file(cred_path)
end

def valid_creds?(username, password)
  creds = load_cred
  binding.pry
  if creds.key?(username)
    bcrypt_password = BCrypt::Password.new(creds[username])
    bcyrpt_password == password
  else
    false
  end
end

def render_markdown(text)
  markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
  markdown.render(text)
end

def load_file(path)
  extention = File.extname(path)
  contents = File.read(path)  

  case extention
  when ".md"
    erb(render_markdown(contents))
  when ".txt"
    headers["Content-Type"] = "text/plain"
    contents
  end  
end

def add_file(new_file)
  allowed_files = ['.txt', '.md']
  filepath = File.join(data_path, new_file)
  if allowed_files.include?(File.extname(filepath))
    File.write(filepath, "")
    session[:message] = "#{new_file} created"
    redirect "/"       
  else
    session[:message] = "Only txt and md files allowed"
    status(422)
    erb(:new)
  end  
end

def signed_in?
  session.key?(:username)
end

def require_user
  unless signed_in?
    session[:message] = "You must be signed in to do that"
    redirect "/"
  end
end

get "/" do
  pattern = File.join(data_path, "*")
  @files = Dir.glob(pattern)
  @files.map! { |filepath| filepath = File.basename(filepath) }.sort!
  erb(:index)    
end

get "/new" do
  require_user

  erb(:new)
end

get "/users/sign_in" do
  erb(:sign_in)
end

get "/:page" do
  filepath = File.join(data_path, params[:page])
  if File.exist?(filepath)
    load_file(filepath)
  else
    session[:message] = params[:page] + " does not exist!"
    redirect "/"
  end
end

get "/:page/edit" do
  require_user

  filepath = File.join(data_path, params[:page])
  @contents = File.read(filepath)
  erb(:edit) 
end


post "/:page/save" do
  require_user

  filepath = File.join(data_path, params[:page])
  new_content = params[:input_content]
  File.write(filepath, new_content)
  session[:message] = "#{params[:page]} has been updated successfully."
  redirect "/"
end

post "/create" do
  require_user

  new_file = params[:new_document]  
  if new_file.empty?
    session[:message] = "No file name provided. Not created."
    status(422)
    erb(:new)
  else
    add_file(new_file)
  end
end

post "/:page/delete" do
  require_user

  filepath = File.join(data_path, params[:page])
  File.delete(filepath)
  session[:message] = "#{params[:page]} deleted!"
  redirect "/"
end

post "/users/sign_in" do
  username = params[:username]
  password = params[:password]

  users = load_cred

  # if users.key?(username) && password == users[username] = password
  if valid_creds?(username, password)
    session[:username] = username
    session[:message] = "Welcome!"
    redirect "/"
  else
    session[:message] = "Authentication failed"
    status 422
    erb(:sign_in)
  end
end

post "/users/sign_out" do
  session.delete(:username)
  session[:message] = "Signed out successfully"
  redirect "/"
end
