require 'net/http'
require 'sinatra'
require 'haml'
require 'cgi'
load 'mtg_price_backend.rb'

card_fetcher = CardDataFetcher.new

get '/' do
  if params[:q]
    results = card_fetcher.run_query(params)
  end
  haml :search, locals: { card_data: results }
end

get '/search'  do
  if params[:q]
    results = card_fetcher.run_query(params)
  end
  haml :search, locals: { card_data: results }
end

get '/search.json' do
  if params[:q]
    results = card_fetcher.run_query(params)
  end
  content_type 'json'
  response = {
    "success" => true,
    "cards" => results
  }
  response.to_json
end

