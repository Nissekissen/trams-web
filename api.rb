# api.rb
#
# JSON API for the iOS app. Mounted at /api (see config.ru).
require_relative 'config/environment'
require 'sinatra/base'
require 'sinatra/namespace'

class TramsApi < Sinatra::Base
  register Sinatra::Namespace

  configure do
    set :method_override, true
  end

  before do
    if request.media_type == 'application/json'
      body = request.body.read
      JSON.parse(body).each { |k, v| params[k] = v } unless body.empty?
    end
  end

  before '/*' do
    next if request.path_info.start_with?('/auth')

    token = request.env['HTTP_AUTHORIZATION']&.sub(/^Bearer /, '')
    halt 401, { error: "Unauthorized" }.to_json if token.nil? || token.empty?

    @current_user = User.find_by(api_token: token)
    halt 401, { error: "Unauthorized" }.to_json unless @current_user
  end

  namespace '/auth' do
    post '/check-email' do
      # get the email and check if an account exists
      # Return either { status: "new" }, { status: "has_password" }, { status: "needs_password" }
      email = params[:email].downcase
      # make sure its a valid email
      unless User.validate_email(email)
        halt 400, { error: "Invalid email" }.to_json
      end

      user = User.find_by(email: email)
      p user
      if user.nil?
        { status: "new" }.to_json
      elsif user.password_set
        { status: "has_password" }.to_json
      else
        { status: "needs_password" }.to_json
      end
    end

    post '/login' do
      email = params[:email].downcase
      password = params[:password]
      user = User.find_by(email: email)
      if user.nil? || !user.password_set
        p "invalid credentials"
        halt 401, { error: "Invalid credentials" }.to_json
      end

      if !user.authenticate(password)
        p "invalid credentials"
        halt 401, { error: "Invalid credentials" }.to_json
      end

      {
        "token": user.generate_token,
        "user": user.to_api_hash
      }.to_json
    end

    post '/signup' do
      email = params[:email].downcase
      password = params[:password]
      password_confirmation = params[:password_confirmation]
      name = params[:name]

      user = User.new(email: email, name: name)
      user.password = password
      user.password_confirmation = password_confirmation

      if user.save
        {
          "token": user.generate_token,
          "user": user.to_api_hash
        }.to_json
      else
        halt 400, { error: user.errors.full_messages.join(", ") }.to_json
      end
    end
  end

  get '/trams' do
    # return a flat list of all trams.
    # should have:
    # id, number, name?, description?, model (id, name), linesSeenOn (list of strings)

    trams = Tram.all
    trams.map do |tram|
      tram.to_api_hash
    end.to_json
  end

  get '/me' do
    # Returns logged in user and some stats
    # id, name, email, riddenTramIds (list of tram ids), stats (rideCount, riddenLineCount, riddenTramCount, totalTramCount, ridesThisWeek)

    @current_user.to_api_hash.to_json
  end

  get '/me/stats' do
    # Returns the user's stats
    # rideCount, riddenLineCount, riddenTramCount, totalTramCount, ridesThisWeek
    @current_user.stats.to_json
  end

  get '/me/rides' do
    # Returns the user's rides as a flat list
    # id, tram, line, occuredAt
    limit = params['limit'] || 10
    rides = @current_user.rides.order(ridden_on: :desc, id: :desc).limit(limit)
    rides.map do |ride|
      ride.to_api_hash
    end.to_json
  end

  post '/rides' do
    # params: tramId, lineNumber, riddenOn
    # returns: { ride, user }

    tram_id = params['tramId']
    line_number = params['lineNumber']
    ridden_on = params['riddenOn']

    ride = Ride.new(tram_id: tram_id, user_id: @current_user.id, line: line_number, ridden_on: ridden_on)
    ride.save

    p({ ride: ride.to_api_hash, user: @current_user.to_api_hash }.to_json)
    # TODO! add error handling here
    { ride: ride.to_api_hash, user: @current_user.to_api_hash }.to_json
  end

  delete '/rides/:id' do
    #TODO!

  end




end
