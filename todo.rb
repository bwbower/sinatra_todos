require "sinatra"
require "sinatra/reloader" if development?
require "tilt/erubis"
require "sinatra/content_for"

configure do
  enable :sessions
  set :session_secret, 'secret'
  set :erb, :escape_html => true
end

helpers do
  # Return an error message if the name is invalid, return nil if valid
  def invalid_list_name?(name)
    if !(1..100).cover? name.size
      "List name must be between 1 and 100 characters."
    elsif session[:lists].any? { |list| list[:name] == name }
      "List name must be unique."
    end
  end

  # Determine if list is complete
  def list_complete?(list)
    "complete" if list[:todos].all? { |todo| todo[:completed] == true } && !list[:todos].empty?
  end

  # Determine number of todos completed
  def todos_remaining(list)
    num_complete = list[:todos].select { |todo| todo[:completed] == true }.size
    "#{num_complete}/#{list[:todos].size}"
  end

  def sort_todos(list)
    list[:todos].partition { |item| !item[:completed] }.flatten
  end

  def sort_lists(lists)
    lists.sort_by! do |list|
      todos_remaining(list).to_r rescue 0
    end
  end

  def invalid_id?(id)
    id > session[:lists].size
  end
end

before do
  session[:lists] ||= []
end

get "/" do
  redirect "/lists"
end

# View list of lists
get "/lists" do
  @lists = session[:lists]
  erb :lists, layout: :layout
end

# Render the new list form
get "/lists/new" do
  erb :new_list, layout: :layout
end

# Create a new list
post "/lists" do
  list_name = params[:list_name].strip
  error = invalid_list_name?(list_name)

  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    session[:lists] << { name: list_name, todos: [] }
    session[:success] = "The list has been created!"
    redirect "/lists"
  end
end

# Display single list
get "/lists/:id" do
  id = params[:id].to_i
  @current_list = session[:lists][id]
  error = invalid_id?(id)

  if error
    session[:error] = "Unable to locate that list!"
    redirect "/lists"
  else
    erb :single_list, layout: :layout
  end
  
end

# Render the edit list form
get "/lists/:id/edit" do
  id = params[:id].to_i
  @current_list = session[:lists][id]
  erb :edit_list
end

# Edit lists
post "/lists/:id/edit" do
  id = params[:id].to_i
  @current_list = session[:lists][id]

  list_name = (params[:list_name] || @current_list[:name]).strip
  error = invalid_list_name?(list_name)

  if error
    session[:error] = error
    erb :edit_list, layout: :layout
  else
    @current_list[:name] = list_name
    session[:success] = "The list has been updated!"
    redirect "/lists/#{id}"
  end
end

# Delete a list
post "/lists/:id/delete" do
  session[:lists].delete_at(params[:id].to_i)
  session[:success] = "The list has been deleted!"
  redirect "/lists"
end

def invalid_item_name?(text)
  if !(1..100).cover? text.size
    "Item name must be between 1 and 100 characters."
  elsif @current_list[:todos].any? { |list| list[:name] == text }
    "Item name must be unique."
  end
end

# Add item to a list
post "/lists/:id/todos" do
  id = params[:id].to_i
  @current_list = session[:lists][id]
  text = params[:todo].strip
  error = invalid_item_name?(text)

  if error
    session[:error] = error
    erb :single_list, layout: :layout
  else
    @current_list[:todos] << {name: text, completed: false }
    session[:success] = "Item has been added to list!"
    redirect "/lists/#{id}"
  end
end

# Remove item from list
post "/lists/:id/remove/:index" do
  id = params[:id].to_i
  @current_list = session[:lists][id]
  @current_list[:todos].delete_at(params[:index].to_i)
  session[:success] = "Item was deleted!"
  redirect "/lists/#{id}"
end

# Complete item on list
post "/lists/:id/todos/:index" do
  id = params[:id].to_i
  @current_list = session[:lists][id]
  @current_item = @current_list[:todos][params[:index].to_i]
  @current_item[:completed] = !@current_item[:completed]
  session[:success] = "List has been updated!"
  redirect "/lists/#{id}"
end

# Complete all items on a list
post "/lists/:id/finish" do
  id = params[:id].to_i
  @current_list = session[:lists][id]
  @current_list[:todos].each { |todo| todo[:completed] = true }
  session[:success] = "All items have been marked as complete!"
  redirect "/lists/#{id}"
end

