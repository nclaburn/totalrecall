require 'rubygems'
require 'sinatra'
require 'data_mapper'
require 'omniauth'
require 'omniauth-twitter'
require 'sinatra/flash'

use Rack::Session::Cookie
enable :sessions

use OmniAuth::Builder do
  provider :twitter, ENV['TWITTER_AUTH_ID'], ENV['TWITTER_SECRET']
end

DataMapper::setup(:default, "sqlite3://#{Dir.pwd}/recall.db")

class User
  include DataMapper::Resource
  property :id,       Serial
  property :provider, String
  property :uid,      String
  property :nickname, String

  has n, :notes, :through => Resource
  def self.create_with_omniauth(auth)
    create(:provider => auth['provider'], uid => auth['uid'], :nickname => auth['info']['nickname'])
  end
end

class Note
  include DataMapper::Resource
  property :id, Serial
  property :content, Text, :required => true
  property :complete, Boolean, :required => true, :default => false
  property :created_at, DateTime
  property :updated_at, DateTime
end

DataMapper.finalize.auto_upgrade!

helpers do
  def current_user
    @current_user ||= User.get(session['user_id']) if session['user_id']
  end
end

get '/auth/:provider/callback' do
  auth = request.env['omniauth.auth']
  user = User.first(:provider => auth['povider'], :uid => auth['uid']) || User.create_with_omniauth(auth)
  session['user_id'] = user.id
  #flash[:message] = "Hello, #{auth['info']['name']}, you logged in via #{params['provider']}"
  redirect '/'
end

get '/' do
  if session['user_id']
    user = User.get session['user_id']
    @notes = user.notes.all :order => :id.desc
    @title = 'All notes'
  end
  erb :home
end

post '/' do
  if session['user_id'].nil?
    flash[:error] = "You must log in"
    redirect '/'
  end
  n = Note.new
  n.content = params[:content]
  n.created_at = Time.now
  n.updated_at = Time.now
  n.save
  user = User.get session['user_id']
  user.notes << n
  user.save!
  redirect '/'
end

get '/:id' do
  if session['user_id'].nil?
    flash[:error] = "You must log in"
    redirect '/'
  end
  user = User.get session['user_id']
  @note = user.notes.get params[:id]
  @title = "Edit note ##{params[:id]}"
  erb :edit
end

put '/:id' do
  if session['user_id'].nil?
    flash[:error] = "You must log in"
    redirect '/'
  end
  user = User.get session['user_id']
  n = user.notes.get params[:id]
  n.content = params[:content]
  n.complete = params[:complete] ? 1 : 0
  n.updated_at = Time.now
  n.save
  redirect '/'
end

get '/:id/delete' do
  if session['user_id'].nil?
    flash[:error] = "You must log in"
    redirect '/'
  end
  user = User.get session['user_id']
  @note = user.notes.get params[:id]
  @title = "Confirm deletion of note ##{params[:id]}"
  erb :delete
end

delete '/:id' do
  if session['user_id'].nil?
    flash[:error] = "You must log in"
    redirect '/'
  end
  user = User.get session['user_id']
  n = user.notes.get params[:id]
  n.destroy
  redirect '/'
end

get '/:id/complete' do
   if session['user_id'].nil?
    flash[:error] = "You must log in"
    redirect '/'
  end
  user = User.get session['user_id']
  n = user.notes.get params[:id]
  n.complete = n.complete ? 0 : 1 #flip
  n.updated_at = Time.now
  n.save
  redirect '/'
end

get '/logout' do
  session['user_id'] = nil
  redirect '/'
end