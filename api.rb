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

  before '/*' do
    @current_user = User.find(1) # TODO: replace with real session/token check
  end

  get '/trams' do
    # return a flat list of all trams.
    # should have:
    # id, number, name?, description?, model (id, name), linesSeenOn (list of strings)

    trams = Tram.all
    trams.map do |tram|
      {
        id: tram.id,
        number: tram.number,
        name: tram.name,
        description: tram.description,
        model: { id: tram.model.id, name: tram.model.name },
        linesSeenOn: tram.lines_seen_on.map(&:to_s)
      }
    end.to_json
  end

  get '/me' do
    # Returns logged in user and some stats
    # id, name, email, riddenTramIds (list of tram ids), stats (rideCount, riddenLineCount, riddenTramCount, totalTramCount, ridesThisWeek)

    {
      id: @current_user.id,
      name: @current_user.name,
      email: @current_user.email,
      riddenTramIds: @current_user.ridden_tram_ids,
      stats: @current_user.stats
    }.to_json
  end

  get '/me/stats' do
    # Returns the user's stats
    # rideCount, riddenLineCount, riddenTramCount, totalTramCount, ridesThisWeek
    @current_user.stats.to_json
  end

  get '/me/rides' do
    # Returns the user's rides as a flat list
    # id, tram, line, occuredAt
    rides = @current_user.rides
    rides.map do |ride|
      {
        id: ride.id,
        tram: { id: ride.tram.id, number: ride.tram.number, name: ride.tram.name, model: { id: ride.tram.model.id, name: ride.tram.model.name } },
        line: { id: ride.line.id, name: ride.line.name },
        occuredAt: ride.ridden_on
      }
    end.to_json
  end

  post '/rides' do
    #TODO!

  end

  delete '/rides/:id' do
    #TODO!

  end




end
