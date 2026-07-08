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
    post '/login' do
      email = params[:email].downcase
      password = params[:password]
      user = User.find_by(email: email)
      if user.nil? || !user.password_set
        halt 401, { error: "Wrong username/password" }.to_json
      end

      if !user.authenticate(password)
        halt 401, { error: "Wrong username/password" }.to_json
      end

      {
        "token": user.generate_token,
        "user": user.to_api_hash
      }.to_json
    end

    post '/google' do
      id_token = params[:id_token]
      halt 400, { error: "Missing id_token" }.to_json if id_token.nil? || id_token.empty?

      begin
        payload = Google::Auth::IDTokens.verify_oidc(id_token, aud: ENV.fetch('GOOGLE_CLIENT_ID'))
      rescue Google::Auth::IDTokens::VerificationError
        halt 401, { error: "Invalid Google Token" }.to_json
      end

      halt 401, { error: "Email not verified" }.to_json unless payload['email_verified']

      user = User.find_by(google_uid: payload['sub'])

      if user.nil?
        user = User.find_by(email: payload['email'])
        if user
          # Link existing account to google
          user.update!(google_uid: payload['sub'])
        else
          # Create new account
          user = User.create!(
            email: payload['email'],
            name: payload['name'],
            google_uid: payload['sub'],
            password: SecureRandom.hex(32),
            password_set: false
          )
        end
      end

      {
        token: user.generate_token,
        user: user.to_api_hash
      }.to_json
    end

  end

  get '/trams' do
    # return a flat list of all trams.
    # should have:
    # id, number, name?, description?, model (id, name), linesSeenOn (list of strings)

    trams = Tram.all
    trams.map(&:to_api_hash).to_json
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
    rides.map(&:to_api_hash).to_json
  end

  post '/rides' do
    # params: tramId, lineNumber, riddenOn
    # returns: { ride, user }

    tram_id = params['tramId']
    line_number = params['lineNumber']
    ridden_on = params['riddenOn']

    halt 422, { error: "Ogiltig spårvagn" }.to_json unless Tram.exists?(tram_id)

    ride = Ride.new(tram_id: tram_id, user_id: @current_user.id, line: line_number, ridden_on: ridden_on)

    if ride.save
      { ride: ride.to_api_hash, user: @current_user.to_api_hash }.to_json
    else
      halt 422, {error: ride.errors.full_messages.join(", ")}.to_json
    end
  end

  delete '/rides/:id' do
    ride = Ride.find_by(id: params['id'], user: @current_user)
    halt 404 unless ride

    ride.destroy
    status 200
    { user: @current_user.to_api_hash }.to_json
  end
end
