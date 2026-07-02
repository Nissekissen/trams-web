# app.rb
require_relative 'config/environment'
require 'sinatra/base'
require 'sinatra/namespace'
require 'securerandom'

class TramsApp < Sinatra::Base
  register Sinatra::Namespace

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

    def current_user
      @current_user ||= User.find_by(id: session[:user_id])
    end

    def logged_in?
      !current_user.nil?
    end

    def require_login
      redirect '/login' unless logged_in?
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
      params.slice('name', 'email', 'password', 'password_confirmation')
    end

    def load_home_data(user_id)
      @models          = Model.includes(:trams).order(:name)
      @total_trams     = Tram.count
      @ride_count      = Ride.where(user_id: user_id).count
      @ridden_tram_ids = Ride.where(user_id: user_id).distinct.pluck(:tram_id).to_set
      @ridden_lines    = Ride.where(user_id: user_id).distinct.pluck(:line).to_set
      week_start       = Date.today - ((Date.today.wday - 1) % 7)
      @week_ride_count = Ride.where(user_id: user_id).where('ridden_on >= ?', week_start).count
      @recent_rides    = Ride.where(user_id: user_id)
                             .includes(tram: :model)
                             .order(ridden_on: :desc, created_at: :desc)
                             .limit(10)
    end
  end

  # ---------------------------------------------------------------
  # Shared before filter
  # ---------------------------------------------------------------
  before do
    @models = Model.includes(:trams).order(:name) if logged_in?
  end

  # ---------------------------------------------------------------
  # Dashboard
  # ---------------------------------------------------------------
  get '/' do
    require_login
    load_home_data(current_user.id)
    erb :index
  end

  # ---------------------------------------------------------------
  # Trams
  # ---------------------------------------------------------------
  namespace '/admin' do

    before '/*' do
      require_login
      p current_user.is_admin
      redirect '/' unless current_user.is_admin
    end

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
      erb :'admin/trams/index'
    end

    get '/trams/new' do
      @tram   = Tram.new
      @models = Model.ordered
      erb :'admin/trams/new'
    end

    post '/trams' do
      @tram = Tram.new(tram_params)
      if @tram.save
        redirect '/trams'
      else
        @models = Model.ordered
        erb :'admin/trams/new'
      end
    end

    get '/trams/:id/edit' do
      @tram   = Tram.find(params['id'])
      @models = Model.ordered
      erb :'admin/trams/edit'
    end

    put '/trams/:id' do
      @tram = Tram.find(params['id'])
      if @tram.update(tram_params)
        redirect '/trams'
      else
        @models = Model.ordered
        erb :'admin/trams/edit'
      end
    end

    delete '/trams/:id' do
      Tram.find(params['id']).destroy
      redirect '/admin/trams'
    end

  end

  # ---------------------------------------------------------------
  # Trams (public)
  # ---------------------------------------------------------------
  get '/trams' do
    require_login
    @ridden_tram_ids = Ride.where(user_id: current_user.id).distinct.pluck(:tram_id).to_set
    @lines_by_tram   = Ride.distinct.pluck(:tram_id, :line).group_by(&:first).transform_values { |v| v.map(&:last).sort }
    erb :'trams/index'
  end

  get '/trams/:id' do
    require_login
    @tram       = Tram.includes(:model).find(params['id'])
    @my_rides   = Ride.where(user_id: current_user.id, tram_id: @tram.id)
                      .order(ridden_on: :desc)
    @seen_lines = Ride.where(tram_id: @tram.id).distinct.pluck(:line).sort
    erb :'trams/show'
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

  get '/login' do
    erb :'auth/login'
  end

  post '/login' do
    user = User.find_by(email: params[:email]&.downcase)
    if user&.authenticate(params['password'])
      session[:user_id] = user.id
      redirect '/'
    end

    @error = 'Fel e-post eller lösenord'
    erb :'auth/login'
  end

  delete '/logout' do
    session.clear
    redirect '/login'
  end

  get '/signup' do
    @user = User.new()
    erb :'auth/signup'
  end

  post '/signup' do
    @user = User.new(user_params)
    @user.email = @user.email&.downcase
    if @user.save
      session[:user_id] = @user.id
      redirect '/'
    else
      erb :'auth/signup'
    end
  end

  # ---------------------------------------------------------------
  # Profile
  # ---------------------------------------------------------------
  get '/profile' do
    require_login
    erb :'profile/show'
  end

  get '/about' do
    require_login
    erb :'about/index'
  end

  get '/privacy' do
    require_login
    erb :privacy
  end

  patch '/profile/password' do
    require_login
    user = current_user
    unless user.authenticate(params['current_password'])
      @password_error = 'Nuvarande lösenord stämmer inte'
      return erb :'profile/show'
    end
    if params['new_password'] != params['new_password_confirmation']
      @password_error = 'De nya lösenorden matchar inte'
      return erb :'profile/show'
    end
    if user.update(password: params['new_password'], password_confirmation: params['new_password_confirmation'])
      @password_success = 'Lösenordet har uppdaterats'
    else
      @password_error = user.errors.full_messages.first
    end
    erb :'profile/show'
  end

  delete '/profile' do
    require_login
    user = current_user
    unless user.authenticate(params['password'])
      @delete_error = 'Fel lösenord'
      return erb :'profile/show'
    end
    user.destroy
    session.clear
    redirect '/login'
  end

  # ---------------------------------------------------------------
  # Rides
  # ---------------------------------------------------------------
  post '/rides' do
    @ride = Ride.new(ride_params)
    if @ride.save
      session[:user_id] = @ride.user_id
      session[:complete_ride_id] = @ride.id
      redirect "/rides/#{@ride.id}/complete"
    else
      load_home_data(@ride.user_id)
      erb :index
    end
  end

  get '/rides/:id/complete' do
    require_login
    redirect '/' unless session.delete(:complete_ride_id) == params['id'].to_i
    @ride            = Ride.includes(tram: :model).find(params['id'])
    user_id          = current_user.id
    @ride_count      = Ride.where(user_id: user_id).count
    @ridden_tram_count = Ride.where(user_id: user_id).distinct.pluck(:tram_id).size
    @total_trams     = Tram.count
    @ridden_lines_count = Ride.where(user_id: user_id).distinct.pluck(:line).size
    @first_ride      = Ride.where(user_id: user_id, tram_id: @ride.tram_id).count == 1
    erb :'rides/complete', layout: false
  end

  delete '/rides/:id' do
    ride = Ride.find(params['id'])
    tram_id = ride.tram_id
    ride.destroy
    redirect "/trams/#{tram_id}"
  end
end
