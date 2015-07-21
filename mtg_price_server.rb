require 'net/http'
require 'sinatra'
require 'haml'
require 'cgi'
load 'mtg_price_backend.rb'

$card_fetcher = CardDataFetcher.new

def render_search_page(params = {})
  if params[:q]
    results = $card_fetcher.run_query(params)
  end
  haml :search, locals: { card_data: results }
end

get '/' do
  render_search_page(params)
end

get '/refresh' do
  $card_fetcher.fetch_cards(true)
  render_search_page
end

get '/search'  do
  render_search_page(params)
end

get '/search.json' do
  if params[:q]
    results = $card_fetcher.run_query(params)
  end
  content_type 'json'
  response = {
    "success" => true,
    "cards" => results
  }
  response.to_json
end

