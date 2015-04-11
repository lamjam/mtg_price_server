require 'net/http'
require 'json'
require 'cgi'
require 'htmlentities'

class CardDataFetcher
  def initialize
    @mtg_data = MtgData.new
    fetch_cards(true)
  end

  def fetch_cards(force_web_request = false)
    unless @cached_response.nil? || force_web_request
      return @cached_response
    end

    uri = URI('http://mtgoclanteam.com/price.php?')
    res = Net::HTTP.get_response(uri)
    if res.is_a?(Net::HTTPSuccess)
      data = parsed_body(res.body)
      @cached_response = {
        :success => true, 
        :data => data, 
        :fetched_at => Time.now
      }
      @cached_response
    else
      {:success => false}
    end
  end

  def run_query(params)
    query_params = parse_query(params[:q])
    card_data = fetch_cards    
    if card_data[:success]
      card_indices = 
        card_data[:data].each_index.select do |i| 
          matches_query?(card_data[:data][i], query_params, params)
        end
      cards = []
      card_indices.each do |i|
        cards << card_data[:data][i]
      end
      cards
    end
  end

  private

  def parse_query(query)
    query_params = {}
    advanced_params_regex = /([\w]+)=([\d\w]+|"[\d\w\s]+")/
    advanced_params = query.scan(advanced_params_regex)
    if advanced_params.length > 0
      advanced_params.each do |keyval|
        if advanced_param_keys.include?(keyval[0])
          query_params[keyval[0]] = keyval[1]
        end
      end
    else
      # assume the entire thing is the name
      query_params['name'] = query
    end
    query_params
  end

  def advanced_param_keys 
    %w(name set text type)
  end

  def matches_query?(card, query_params, params)    
    if query_params['name']
      return false unless card[:name].downcase.include? query_params['name'].downcase
    end
    if query_params['set']
      return false unless card[:set].downcase.include? query_params['set'].downcase
    end    
    if query_params['text']      
      return false unless card[:text] && card[:text].downcase.include?(query_params['text'].downcase)
    end
    if query_params['type']
      return false unless card[:type].downcase.include? query_params['type'].downcase
    end
    if params[:format]
      return false unless sets_in_format(params[:format]).include? card[:set].upcase
    end
    true
  end

  def parsed_body(body)    
    start_php = '{ "aaData"'
    end_php = '<?php endif'
    start_json = body.index(start_php)
    end_json = body.index(end_php) - 1    
    json_string = body[start_json..end_json]
    json_data = JSON.parse(json_string)
    formatted_data = []
    html_coder = HTMLEntities.new
    json_data["aaData"].each do |item|
      mtg_card_data = @mtg_data.get_card_info(item[0], item[1]) || {}
      formatted_data << {
        :set => item[0],
        :name => item[1],
        :rarity => item[2],
        :rarity_short => item[2][0],
        :buy_price => item[3],
        :sell_price => item[4],
        :link_to_card_info => link_to_card_info(item[1]),
        :type => html_coder.encode(mtg_card_data['type']),
        :text => html_coder.encode(mtg_card_data['text']),
        :mana_cost => html_coder.encode(mtg_card_data['manaCost']),
        :link_to_card_image => link_to_card_image(item[0], mtg_card_data['number'])
      }
    end
    puts formatted_data[0][:type], html_coder.decode(formatted_data[0][:type])
    formatted_data
  end

  def link_to_card_info(card_name)
    name = CGI.escape(card_name.downcase)
    return "http://magiccards.info/query?q=#{name}&v=card&s=cname"
  end

  def link_to_card_image(set, set_number)
    "http://magiccards.info/scans/en/#{set.downcase}/#{set_number}.jpg"
  end

  def sets_in_format(format)
    case format
    when 'standard'
      %w(DTK FRF KTK M15 BNG JOU THS)
    else
      nil
    end
  end
end

class MtgData
  def initialize
    card_info_json = JSON.parse(File.read('AllSets.json'))
    @card_info_hash = {}
    card_info_json.each do |set_code, set_data|
      @card_info_hash[set_code] = {}
      card_info_json[set_code]['cards'].each do |card|
        card_name = card['names'] ? card['names'].join(' // ') : card['name']
        @card_info_hash[set_code][card_name.downcase] = card
      end
    end
  end

  def get_card_info(set, card_name)    
    @card_info_hash[set.upcase][card_name.downcase]
  end
end