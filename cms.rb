require "sinatra"
require "sinatra/reloader"
require "tilt/erubis"
require "redcarpet"
require "pry"

# root = File.expand_path("..", __FILE__)

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

get "/" do
  pattern = File.join(data_path, "*")
  @files = Dir.glob(pattern)
  @files.map! { |filepath| filepath = File.basename(filepath) }.sort!
  erb(:index)
end

get "/:page" do
  filepath = File.join(data_path, params[:page])
  if File.exist?(filepath)
    load_file(filepath)
  else
    session[:message] = params[:page] + " does not exist!" unless params[:page] == "favicon.ico"
    redirect "/"
  end
end

get "/:page/edit" do
  filepath = File.join(data_path, params[:page])
  @contents = File.read(filepath)
  erb(:edit) 
end

post "/:page/save" do
  filepath = File.join(data_path, params[:page])
  new_content = params[:input_content]
  File.write(filepath, new_content)
  session[:message] = "#{params[:page]} has been updated successfully."
  redirect "/"
end