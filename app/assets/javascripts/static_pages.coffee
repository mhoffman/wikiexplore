# Place all the behaviors and hooks related to the matching controller here.
# All this logic will automatically be available in application.js.
# You can use CoffeeScript in this file: http://coffeescript.org/
$ ->

    zoom = 12
    center = ol.proj.fromLonLat([-122.18333, 37.452778])
    console.log(center)
    rotation = 0
    if window.location.hash != ''
        hash = window.location.hash.replace('#map=', '')
        parts = hash.split('/')
        if  parts.length == 4
            zoom = parseInt(parts[0], 10)
            center = [parseFloat(parts[1]), parseFloat(parts[2])]
            rotation = parseFloat(parts[3])


    map = new ol.Map
        target: 'map'
        layers: [
            new ol.layer.Tile
                source: new ol.source.MapQuest
                    layer: 'osm'
                ]
        view: new ol.View
            #projection: 'EPSG:4326'
            center: ol.proj.fromLonLat([13.31, 52.50])
            zoom: zoom
            center: center
            rotation: rotation

    shouldUpdate = true
    view = map.getView()

    updatePermalink = () ->
        if !shouldUpdate
            shouldUpdate = true
            return

        center = view.getCenter()
        hash = "#map=#{view.getZoom()}/#{Math.round(center[0]*100)/100}/#{Math.round(center[1]*100)/100}/#{view.getRotation()}"

        coords = ol.proj.toLonLat(view.getCenter())
        $.ajax
            type: 'POST'
            url: "#{window.location.protocol}//#{window.location.host}/localwikisearch"
            data:
                coords: "#{coords[1]},#{coords[0]}"
                lang: (window.navigator.userLanguage || window.navigator.language).split('-')[0]
            success: (data, textStatus, jqXHR) ->
                for wiki_entry in data.data
                    do (wiki_entry) ->
                        center = ol.proj.fromLonLat([wiki_entry.lon, wiki_entry.lat])
                        #console.log(wiki_entry)
                        lang = window.navigator.userLanguage || window.navigator.language
                        lang = lang.split('-')[0]
                        console.log(lang)
                        url = "http://#{lang}.wikipedia.org/?curid=#{wiki_entry.pageid}"
                        overlay = new ol.Overlay
                            position: center
                            element: $("<p style=\"max-width:80px; word-wrap:break-word; line-height:80%; background-color:white;font-size:8pt;\"><a target=\"_new\" href=\"#{url}\" style=''>#{wiki_entry.title}</a></p>")[0]

                        map.addOverlay(overlay)

            fail: (data, textStatus, error) ->
                console.log("Could not find wiki entry for #{coords} #{textStatus}")
            always: (data, text, error) ->
                console.log("Always #{text}")

        state =
            zoom: view.getZoom()
            center: view.getCenter()
            rotation: view.getRotation()
        window.history.pushState(state, 'map', hash)

    map.on 'moveend', updatePermalink

    window.addEventListener 'popstate', (event) ->
        if event.state == null
            return
        map.getView().setCenter(event.state.center)
        map.getView().setZoom(event.state.zoom)
        map.getView().setRotation(event.state.rotation)
        shouldUpdate = false


    
    $("#center-home").on 'click', (e) ->
        center_navigator = (position) ->
            center = ol.proj.fromLonLat([position.coords.longitude, position.coords.latitude])
            map.getView().setCenter(center)
        navigator.geolocation.getCurrentPosition(center_navigator)

    $("#lookup_form").submit (e) ->
        e.preventDefault()
        $.ajax
            type: 'POST'
            url: "#{window.location.protocol}//#{window.location.host}/localwikilookup"

            data: $("#lookup_form").serialize()

            success : (data) ->
                console.log("Received #{data}")
                center = [parseFloat(data["lonlat"][0]), parseFloat(data["lonlat"][1])]
                console.log(data["lonlat"])
                console.log(center)
                center = ol.proj.fromLonLat(center)
                console.log("At OL #{center}")
                map.getView().setCenter(center)
                map.getView().setZoom("12")

            fail:
                console.log("Something went wrong!")


    # keep it around for debugging
    $(document).data('view', view)
    $(document).data('map', map)
