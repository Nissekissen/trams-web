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
    # In production, a missing SESSION_SECRET must crash the boot, not silently
    # mint a fresh one — a fresh secret invalidates every signed session cookie,
    # logging everyone out on every restart/deploy. Dev/test keep the random
    # fallback since no persistent secret is configured for them.
    set :session_secret, APP_ENV == 'production' ? ENV.fetch('SESSION_SECRET') : ENV.fetch('SESSION_SECRET') { SecureRandom.hex(64) }
    set :sessions, expire_after: 60 * 60 * 24 * 30
  end

  # ---------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------
  helpers do
    def h(text)
      Rack::Utils.escape_html(text.to_s)
    end

    def initials(name)
      name.to_s.split.first(2).map { |word| word[0] }.join.upcase
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

    # Ranks lines by ride count. Returns each segment with pre-computed SVG
    # stroke-dasharray/dashoffset so the view can render a donut without JS.
    def donut_segments(lines, radius: 66)
      ranked = lines.map { |num, data| { line: num, rides: data[:rides] } }
                    .select { |d| d[:rides].positive? }
                    .sort_by { |d| -d[:rides] }
      return [] if ranked.empty?

      segments = ranked.map do |d|
        colors = Ride.color_for(d[:line])
        { line: d[:line], rides: d[:rides], bg: colors[:bg] }
      end

      total = segments.sum { |s| s[:rides] }
      circumference = 2 * Math::PI * radius
      offset = 0

      segments.each do |seg|
        length = (seg[:rides].to_f / total) * circumference
        seg[:percent]  = ((seg[:rides].to_f / total) * 1000).round / 10.0
        seg[:dasharray]  = "#{length} #{circumference - length}"
        seg[:dashoffset] = -offset
        offset += length
      end

      segments
    end

    # Evenly-spaced gridline values (0..max) for the activity bar chart.
    def activity_gridlines(monthly)
      max = monthly.map { |m| m[:rides] }.max.to_i
      return [0] if max.zero?

      [0, (max / 3.0).round, (max * 2 / 3.0).round, max].uniq
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
    return erb :landing, layout: :layout_landing unless logged_in?

    load_home_data(current_user.id)
    erb :index
  end

  # ---------------------------------------------------------------
  # Statistics
  # ---------------------------------------------------------------
  get '/statistics' do
    require_login
    @stats = current_user.detailed_stats
    erb :'statistics/show'
  end

  # ---------------------------------------------------------------
  # Rides
  # ---------------------------------------------------------------
  get '/rides' do
    require_login

    @models = Model.order(:name)
    @selected_lines = Array(params[:lines]).map(&:to_i).select { |line| Ride::LINES.include?(line) }
    @selected_model_ids = Array(params[:model_ids]).map(&:to_i)
    @from = params[:from]
    @to = params[:to]
    @filters_active = @selected_lines.any? || @selected_model_ids.any? || @from.present? || @to.present?

    scope = Ride.where(user_id: current_user.id)
    scope = scope.where(line: @selected_lines) if @selected_lines.any?
    scope = scope.joins(:tram).where(trams: { model_id: @selected_model_ids }) if @selected_model_ids.any?
    scope = scope.where('ridden_on >= ?', @from) if @from.present?
    scope = scope.where('ridden_on <= ?', @to) if @to.present?

    per_page = 20
    @total_count = scope.count
    @total_pages = [(@total_count / per_page.to_f).ceil, 1].max
    @page = [params[:page].to_i, 1].max
    @page = @total_pages if @page > @total_pages

    @rides = scope.includes(tram: :model)
                  .order(ridden_on: :desc, id: :desc)
                  .offset((@page - 1) * per_page)
                  .limit(per_page)

    erb :'rides/index'
  end

  # ---------------------------------------------------------------
  # Trams
  # ---------------------------------------------------------------
  namespace '/admin' do

    before '/*' do
      require_login
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

    get '/users' do
      @users = User.ordered
      ride_counts = Ride.group(:user_id).count
      tram_counts = Ride.group(:user_id).distinct.count(:tram_id)
      line_counts = Ride.group(:user_id).distinct.count(:line)

      @stats_by_user = @users.each_with_object({}) do |user, hash|
        hash[user.id] = {
          rides: ride_counts.fetch(user.id, 0),
          trams: tram_counts.fetch(user.id, 0),
          lines: line_counts.fetch(user.id, 0)
        }
      end

      erb :'admin/users/index'
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
    erb :'auth/login', layout: false
  end

  post '/login' do
    user = User.find_by(email: params[:email]&.downcase)
    if user&.authenticate(params['password'])
      session[:user_id] = user.id
      redirect '/'
    end

    @error = 'Fel e-post eller lösenord'
    erb :'auth/login', layout: false
  end

  post '/auth/google' do
    id_token = JSON.parse(request.body.read)['id_token']

    begin
      user = User.from_google_id_token(id_token)
    rescue Google::Auth::IDTokens::VerificationError
      halt 401, 'Ogiltig Google-inloggning'
    end
    halt 401, 'E-postadressen är inte verifierad hos Google' if user.nil?

    session[:user_id] = user.id
    redirect '/'
  end

  delete '/logout' do
    session.clear
    redirect '/login'
  end

  get '/signup' do
    session.delete(:claim_user_id)
    @email = params['email']
    erb :'auth/signup_step1', layout: false
  end

  post '/signup/start' do
    email = params['email']&.downcase&.strip
    if email.nil? || email.empty?
      @error = 'Ange en e-postadress'
      @email = email
      return erb :'auth/signup_step1', layout: false
    end
    unless email.match?(URI::MailTo::EMAIL_REGEXP)
      @error = 'Ogiltig e-postadress'
      @email = email
      return erb :'auth/signup_step1', layout: false
    end
    existing = User.find_by(email: email)
    if existing && !existing.password_set?
      session[:claim_user_id] = existing.id
      redirect '/signup/claim'
    else
      @error = 'Inget konto hittades för den e-postadressen. Skapa ett nytt konto med Google på inloggningssidan.'
      @email = email
      erb :'auth/signup_step1', layout: false
    end
  end

  get '/signup/claim' do
    user_id = session[:claim_user_id]
    redirect '/signup' unless user_id
    @user = User.find_by(id: user_id)
    redirect '/signup' unless @user && !@user.password_set?
    erb :'auth/claim', layout: false
  end

  post '/signup/claim' do
    user_id = session[:claim_user_id]
    redirect '/signup' unless user_id
    @user = User.find_by(id: user_id)
    redirect '/signup' unless @user && !@user.password_set?
    if @user.update(password: params['password'], password_confirmation: params['password_confirmation'], password_set: true)
      session.delete(:claim_user_id)
      session[:user_id] = @user.id
      redirect '/'
    else
      @errors = @user.errors.full_messages
      erb :'auth/claim', layout: false
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
    erb :'about/index', layout: (logged_in? ? :layout : :layout_landing)
  end

  get '/privacy' do
    erb :privacy, layout: (logged_in? ? :layout : :layout_landing)
  end

  get '/terms' do
    erb :terms, layout: (logged_in? ? :layout : :layout_landing)
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
    if user.update(password: params['new_password'], password_confirmation: params['new_password_confirmation'], password_set: true)
      @password_success = 'Lösenordet har uppdaterats'
    else
      @password_error = user.errors.full_messages.first
    end
    erb :'profile/show'
  end

  post '/profile/link_google' do
    require_login
    id_token = JSON.parse(request.body.read)['id_token']

    begin
      payload = User.verify_google_id_token(id_token)
    rescue Google::Auth::IDTokens::VerificationError
      halt 401, 'Ogiltig Google-inloggning'
    end
    halt 401, 'E-postadressen är inte verifierad hos Google' unless payload['email_verified']
    halt 409, 'Det Google-kontot är redan länkat till ett annat Trams-konto' if User.where(google_uid: payload['sub']).where.not(id: current_user.id).exists?

    current_user.update!(google_uid: payload['sub'])
    redirect '/profile'
  end

  delete '/profile' do
    require_login
    user = current_user
    if user.password_set? && !user.authenticate(params['password'])
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
    require_login
    ride = Ride.find(params['id'])
    halt 401 if ride.user_id != current_user.id && !current_user.is_admin
    tram_id = ride.tram_id
    ride.destroy

    redirect_to = params['redirect_to']
    if redirect_to && redirect_to.start_with?('/') && !redirect_to.start_with?('//')
      status 302
      headers['Location'] = redirect_to
      halt
    else
      redirect "/trams/#{tram_id}"
    end
  end
end
