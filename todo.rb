require 'sinatra'
require 'sinatra/reloader' if development?
require 'sinatra/content_for'
require 'tilt/erubis'

configure do
  enable :sessions
  set :session_secret, 'secret'
end

helpers do
  def list_complete?(list)
    !list[:todos].empty? && list[:todos].all?{ |todo| todo[:completed] }
  end

  def complete?(item)
    if item[:completed] # item is a complete todo
      true
    elsif item[:todos]  # item is a list
      list_complete?(item)
    end
  end

  def list_class(list)
    "complete" if list_complete?(list)
  end

  def todo_class(todo)
    "complete" if todo[:completed]
  end

  def remaining_todos(list)
    total = list[:todos].size
    remaining = list[:todos].count { |todo| !todo[:completed] }
    "#{remaining}/#{total}"
  end

  def completion_sort(items, &block)
    complete_items = {}
    incomplete_items = {}
    items.each_with_index do |item, index|
      if complete?(item)
        complete_items[index] = item
      else
        incomplete_items[index] = item
      end
    end
    incomplete_items.each { |original_index, item| yield(item, original_index) }
    complete_items.each { |original_index, item| yield(item, original_index) }    
  end
end

before do
  session[:lists] ||= []
end

get '/' do
  redirect '/lists'
end

# View all lists
get '/lists' do
  @lists = session[:lists]

  erb :lists, layout: :layout
end

# Render the new list form
get '/lists/new' do
  erb :new_list, layout: :layout
end

# Return an error message if the name is invalid. Return nil if name is valid.
def error_for_list_name(name)
  if !(1..100).cover?(name.size)
    'List name must be between 1 and 100 characters.'
  elsif session[:lists].any? { |list| list[:name] == name }
    'List name must be unique'
  end
end

# Return an error message if the name is invalid. Return nil if name is valid.
def error_for_todo(name)
  if !(1..100).cover?(name.size)
    'Todo name must be between 1 and 100 characters.'
  end
end

# Create a new list
post '/lists' do
  list_name = params[:list_name].strip
  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    session[:lists] << { name: list_name, todos: [] }
    session[:success] = 'The list has been created.'
    redirect '/lists'
  end
end

# View particular list
get '/lists/:id' do
  @list_id = params['id'].to_i
  @list = session[:lists][@list_id]

  erb :list, layout: :layout
end

# Edit an existing todo list
get '/lists/:id/edit' do
  @list = session[:lists][params['id'].to_i]

  erb :edit_list, layout: :layout
end

# Update an existing todo list
post '/lists/:id' do
  list_name = params[:list_name].strip
  id = params['id'].to_i
  @list = session[:lists][id]

  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :edit_list, layout: :layout
  else
    @list[:name] = list_name
    session[:success] = 'The list has been updated.'
    redirect "/lists/#{id}"
  end
end

# Delete a todo list
post '/lists/:id/destroy' do
  id = params[:id].to_i
  session[:lists].delete_at(id)
  session[:success] = "The list has been deleted."
  redirect "/lists"
end

# Add a todo to a list
post '/lists/:list_id/todos' do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]
  text = params[:todo].strip

  error = error_for_todo(text)
  if error
    session[:error] = error
    erb :list, layout: :layout
  else
    @list[:todos] << { name: text, completed: false }
    session[:success] = "Item successfully added to list."
    redirect "/lists/#{@list_id}"
  end
end

# Remove a todo from a list
post '/lists/:list_id/todos/:todo_id/destroy' do
  @list_id = params[:list_id].to_i
  list = session[:lists][@list_id]
  todo_id = params[:todo_id].to_i
  
  list[:todos].delete_at(todo_id)
  session[:success] = 'Todo item deleted.'
  redirect "/lists/#{@list_id}"
end

# Toggle completion status of todo item
post '/lists/:list_id/todos/:todo_id' do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]
  todo_id = params[:todo_id].to_i
  todo = @list[:todos][todo_id]

  is_completed = params[:completed] == 'true'
  todo[:completed] = is_completed

  session[:success] = 'The todo has been updated.'
  redirect "/lists/#{@list_id}"
end

# Complete all todos in a list
post '/lists/:list_id/complete_all' do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]
  
  @list[:todos].each do |todo|
    todo[:completed] = true
  end  
  session[:success] = 'All todo items have been updated.'
  redirect "/lists/#{@list_id}"
end  
