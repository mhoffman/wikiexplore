
require 'httpclient'
require 'cgi'

class LocalWikiController < ApplicationController
  skip_before_filter :verify_authenticity_token
  def search
        coords = params[:coords]
        lon, lat = coords.split(',')
        lang = params[:lang]

        client = HTTPClient.new
        raw_data = client.get_content("https://#{lang}.wikipedia.org/w/api.php?action=query&list=geosearch&gscoord=#{lon}%7C#{lat}&gsradius=10000&gslimit=500&format=json")
        data = JSON.parse(raw_data)["query"]["geosearch"]
        render :json => {
            :data => data,
            :status => :ok,
            :coords => coords,
        }
  end

  def lookup
    query = params[:query]
    client = HTTPClient.new
    equery = CGI::escape(query)
    raw_data = client.get_content("http://nominatim.openstreetmap.org/search/#{CGI::escape query}?format=json&polygon=0&addressdetails=1")
    data = JSON.parse(raw_data)
    if data.size > 0 then
        first_hit = data[0]
 
        render :json => {
            :message => "Found something",
            :name => first_hit["display_name"],
            :lon => first_hit["lon"].to_f,
            :lat => first_hit["lat"].to_f,
            :lonlat  => [first_hit["lon"], first_hit["lat"],],
            :first_hit => first_hit,
            :status => 200,
 
        }
    else
        render :json => {
            :message => "Oh, nothing found.",
            :status => 404,
        }
    end
  end
 
  def getcategories
     lang = params[:lang]
     query = params[:query]
     client = HTTPClient.new
     equery = CGI::escape(query)
     raw_data = client.get_content("https://#{lang}.wikipedia.org/w/api.php?action=query&titles=#{equery}&prop=categories&format=json&cllimit=500")
     data = JSON.parse(raw_data)

     render :json => {
        :data => data,
      }
  end

  def suggest
        coords = params[:coords]
        lon, lat = coords.split(',')
        lang = params[:lang]

        client = HTTPClient.new
        raw_data = client.get_content("https://#{lang}.wikipedia.org/w/api.php?action=query&list=geosearch&gscoord=#{lon}%7C#{lat}&gsradius=10000&gslimit=500&format=json")
        data = JSON.parse(raw_data)["query"]["geosearch"]

        data.sort_by! {|obj| obj["dist"]}

        render :json => {
            :suggestion => data[Random.rand(10)]
        }

    # process liked and unliked categories
      # possible preferences
        # - notinterested : mark categories as -1, mark location as visited, make new suggestion
        # - beentheredonethat : mark categories as +1, mark location as visited, make new suggestion
        # - tellmemore : mark categories as +1, open details window
        # - letsgo : mark categories as +1, mark as visited, return route

    # fetch new targets

    # rank target on distance on categories preferences

  end


end
