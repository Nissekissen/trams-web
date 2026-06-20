# app.rb
require_relative 'config/environment'
require 'sinatra/base'
require 'securerandom'

class TramsApp < Sinatra::Base
  configure do
    set :views, File.join(ROOT, 'views')
    set :public_folder, File.join(ROOT, 'public')
    set :method_override, true
    enable :sessions
    set :session_secret, ENV.fetch('SESSION_SECRET') { SecureRandom.hex(64) }
  end

  # ---------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------
  helpers do
    def h(text)
      Rack::Utils.escape_html(text.to_s)
    end

    def nav_active?(path)
      path == '/' ? request.path_info == '/' : request.path_info.start_with?(path)
    end

    def tram_params
      params.slice('number', 'name', 'description', 'model_id')
    end

    def model_params
      params.slice('name', 'description')
    end

    def ride_params
      params.slice('user_id', 'tram_id', 'line', 'ridden_on')
    end

    def user_params
      params.slice('name')
    end

    # Everything the homepage needs once a user is (or isn't) selected.
    def load_home_data(user_id)
      @users  = User.ordered
      @models = Model.includes(:trams).order(:name)
      @selected_user_id = user_id

      return unless user_id

      @ride_count      = Ride.where(user_id: user_id).count
      @ridden_tram_ids = Ride.where(user_id: user_id).distinct.pluck(:tram_id).to_set
      @ridden_lines    = Ride.where(user_id: user_id).distinct.pluck(:line).to_set
    end
  end

  # ---------------------------------------------------------------
  # Dashboard
  # ---------------------------------------------------------------
  get '/' do
    selected_user_id = params['user_id'] ? params['user_id'].to_i : session[:user_id]
    session[:user_id] = selected_user_id if selected_user_id
    load_home_data(selected_user_id)
    erb :index
  end

  # ---------------------------------------------------------------
  # Trams
  # ---------------------------------------------------------------
  get '/trams' do
    @models = Model.ordered
    @selected_model_ids = if params['filtered']
                             Array(params['model_ids']).map(&:to_i)
                           else
                             @models.map(&:id)
                           end
    @trams_by_model = Tram.where(model_id: @selected_model_ids)
                           .includes(:model)
                           .order(:number)
                           .group_by(&:model)
    erb :'trams/index'
  end

  get '/trams/new' do
    @tram   = Tram.new
    @models = Model.ordered
    erb :'trams/new'
  end

  post '/trams' do
    @tram = Tram.new(tram_params)
    if @tram.save
      redirect '/trams'
    else
      @models = Model.ordered
      erb :'trams/new'
    end
  end

  delete '/trams/:id' do
    Tram.find(params['id']).destroy
    redirect '/trams'
  end

  # ---------------------------------------------------------------
  # Models
  # ---------------------------------------------------------------
  get '/models/new' do
    @model = Model.new
    erb :'models/new'
  end

  post '/models' do
    @model = Model.new(model_params)
    if @model.save
      redirect '/trams'
    else
      erb :'models/new'
    end
  end

  # ---------------------------------------------------------------
  # Users
  # ---------------------------------------------------------------

  get '/users/new' do
    @user = User.new
    erb :'users/new'
  end

  post '/users' do
    @user = User.new(user_params)
    if @user.save
      redirect '/'
    else
      erb :'users/new'
    end
  end

  # ---------------------------------------------------------------
  # Rides
  # ---------------------------------------------------------------
  get '/rides' do
    @users = User.ordered
    @selected_user_id = params['user_id'] ? params['user_id'].to_i : session[:user_id]

    if @selected_user_id
      session[:user_id] = @selected_user_id
      @rides = Ride.where(user_id: @selected_user_id)
                   .includes(tram: :model)
                   .order(ridden_on: :desc, created_at: :desc)
    end

    erb :'rides/index'
  end

  post '/rides' do
    @ride = Ride.new(ride_params)
    if @ride.save
      session[:user_id] = @ride.user_id
      redirect '/'
    else
      load_home_data(@ride.user_id)
      erb :index
    end
  end

  delete '/rides/:id' do
    Ride.find(params['id']).destroy
    redirect '/rides'
  end
end
