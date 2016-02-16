
require 'httpclient'
require 'cgi'
require 'digest'

class String
  def is_integer?
    self.to_i.to_s == self
  end
end


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

     if query.is_integer? then
       raw_data = client.get_content("https://#{lang}.wikipedia.org/w/api.php?action=query&pageids=#{query}&prop=categories&format=json&cllimit=500")
       query_type = 'pageid'
     else
       raw_data = client.get_content("https://#{lang}.wikipedia.org/w/api.php?action=query&titles=#{equery}&prop=categories&format=json&cllimit=500")
       query_type = 'title'
     end

     data = JSON.parse(raw_data)

     render :json => {
        :data => data,
        :query_type => query_type,
      }
  end

  def suggest
      coords = params[:coords]
      lon, lat = coords.split(',')
      lang = params[:lang]
      skip = params[:skip].to_i
      pageid = params[:pageid].to_i

      if pageid == 0 then
          client = HTTPClient.new
          raw_data = client.get_content("https://#{lang}.wikipedia.org/w/api.php?action=query&list=geosearch&gscoord=#{lon}%7C#{lat}&gsradius=10000&gslimit=500&format=json")
          data = JSON.parse(raw_data)["query"]["geosearch"][0..49]

          pdata = {}
          data.each do |x|
            pdata[x["pageid"]] = x
          end

          debug = data.collect{|x| x["pageid"]}.join("|")
          pageids = CGI::escape(data.collect{|x| x["pageid"]}.join("|"))
          
          categories = JSON.parse(
              client.get_content("https://#{lang}.wikipedia.org/w/api.php?action=query&pageids=#{pageids}&prop=categories&format=json&cllimit=5000")
          )["query"]["pages"]

          ranked_data = []
          pdata.each do |pageid, page|
              ranked_data_item = page
              ranked_data_item["ranked_dist"] = ranked_data_item["dist"]
              ranked_data.append(ranked_data_item)

              category_list = categories[pageid.to_s]
              if not category_list["categories"].nil? then
                  category_list["categories"].each do |category_name|
                      ranked_data_item["debug"] = category_name["title"]
                      category = Category.find_by(:name=>category_name["title"])
                      if not category.nil? then
                          ranked_data_item[category.name] = category.id
                          propensity = Propensity.find_by(:category_id=>category.id, :user_id=>current_user.id)
                          if not propensity.nil? then
                              ranked_data_item["Category #{category_name["title"]} #{category.id} User #{current_user.id}"] = propensity.value
                              # higher propensity means that the target appear closer
                              # therefore we need a negative sign here
                              ranked_data_item["ranked_dist"] += - propensity.value * 100
                          else
                              ranked_data_item["propensity"] = "nil"
                          end
                      end
                  end
              end
          end

          ranked_data.sort_by! {|obj| obj["ranked_dist"]}

          suggestion = ranked_data[skip]
          pageid = suggestion["pageid"]

          # retrieve a summary
          raw_summary = client.get_content("https://#{lang}.wikipedia.org/w/api.php?format=json&action=query&prop=extracts&exintro=&explaintext=&pageids=#{pageid}")
          summary = JSON.parse(raw_summary)["query"]["pages"].values[0]["extract"]

          # retrieve image URLs
          raw_images = client.get_content("https://#{lang}.wikipedia.org/w/api.php?action=query&pageids=#{pageid}&prop=images&format=json&cllimit=500")
          image_data = JSON.parse(raw_images)["query"]["pages"].values[0]["images"]
          #debug = image_data
          image_urls = []
          if not image_data.nil? then
              image_data.each do |image|
                title = image["title"]
                fn = title.split(":")[-1].gsub(" ", "_")
                h = Digest::MD5.hexdigest(fn)
                image_urls.append(
                    "https://upload.wikimedia.org/wikipedia/commons/#{h[0]}/#{h[0..1]}/#{fn}"
                )
              end
          end
         info = nil
      else
          suggestion = {}
          info = get_info(pageid, lang)
          #suggestion["info"] = info
          ranked_data = nil
          summary = get_summary(pageid, lang)
          image_urls = get_image_urls(pageid, lang)
          suggestion["title"] = info["title"]
      end

      suggestion["summary"] = summary
      suggestion["info"] = info

      render :json => {
          :pageid => pageid,
          :suggestion => suggestion,
          :ranked_data => ranked_data,
          :categories => categories,
          :image_urls => image_urls,
          :skip => skip,
          :debug => debug,
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

  def vote
    score = params[:score].to_i
    pageid = params[:pageid]
    lang = params[:lang]

    # fetch all categories for page
    client = HTTPClient.new
    raw_data = client.get_content("https://#{lang}.wikipedia.org/w/api.php?action=query&pageids=#{pageid}&prop=categories&format=json&cllimit=500")
    categories_data = JSON.parse(raw_data)["query"]["pages"].values[0]["categories"]

    # for each category, create if doesn't yet exist in db
    categories = []
    categories_data.each do |item|
      category = Category.find_or_create_by(:name=>item["title"])
      categories.append(category)
    end

    debug_data = []
    # for each category decrease user propensity value by score
    categories.each do |category|
      propensity = Propensity.find_or_create_by(:user_id=>current_user.id, :category_id=>category.id)
      propensity.value ||= 0
      propensity.value += score
      propensity.save
      debug_data.append("User #{current_user.id} Category #{category.name} #{category.id} Propensity #{propensity.value}")
    end
   

    render :json => {
     :message => "success",
     :debug => debug_data,
    }

  end

  private

  def get_info(pageid, lang)
      client = HTTPClient.new
      return JSON.parse(client.get_content("https://#{lang}.wikipedia.org/w/api.php?action=query&pageids=#{pageid}&prop=info&format=json"))["query"]["pages"].values[0]
  end

  def get_summary(pageid, lang)
      # retrieve a summary
      client = HTTPClient.new
      raw_summary = client.get_content("https://#{lang}.wikipedia.org/w/api.php?format=json&action=query&prop=extracts&exintro=&explaintext=&pageids=#{pageid}")
      summary = JSON.parse(raw_summary)["query"]["pages"].values[0]["extract"]
      return summary
  end

  def get_image_urls(pageid, lang)
      # retrieve image URLs
      client = HTTPClient.new
      raw_images = client.get_content("https://#{lang}.wikipedia.org/w/api.php?action=query&pageids=#{pageid}&prop=images&format=json&cllimit=500")
      image_data = JSON.parse(raw_images)["query"]["pages"].values[0]["images"]
      #debug = image_data
      image_urls = []
      if not image_data.nil? then
          image_data.each do |image|
            title = image["title"]
            fn = title.split(":")[-1].gsub(" ", "_")
            h = Digest::MD5.hexdigest(fn)
            image_urls.append(
                "https://upload.wikimedia.org/wikipedia/commons/#{h[0]}/#{h[0..1]}/#{fn}"
            )
          end
      end
      return image_urls
  end


end
