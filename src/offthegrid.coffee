# Description:
#   The ultimate Off the Grid Hubot companion.
#
# Dependencies:
#   "cheerio": "0.12.x"
#   "request": "^2.36.0"
#   "moment": "^2.6.0"
#
# Configuration:
#   HUBOT_OFF_THE_GRID_LOCATION_ID
#
# Commands:
#   hubot offthegrid list - Pulls a list of all Off the Grid locations
#   hubot offthegrid <location name> - Pulls today's hours and vendors for a given location
#   hubot offthegrid - Pulls today's hours and vendors for the configured location
#
# Author:
#   jonursenbach

request = require 'request'
cheerio = require 'cheerio'
moment = require 'moment'

now = moment()
today = {
  month: now.format('M'),
  day: now.format('D'),
  year: now.format('YYYY')
}

options = {
  headers: {
    'User-Agent': 'hubot-offthegrid (http://github.com/jonursenbach/hubot-offthegrid)'
  }
}

module.exports = (robot) =>
  ###
  ## Pulls a list of all available locations.
  ###
  robot.respond /(offthegrid|otg) list$/i, (msg) ->
    getLocations msg, (locations) =>
      emit = "Off the Grid locations:\n"
      availableLocations = []

      for i of locations
        location = locations[i]
        availableLocations.push(" · #{location.name} (#{location.region})");

      emit += availableLocations.join("\n")

      msg.send emit

  ###
  ## Pulls the internal ID for a given location.
  ###
  robot.respond /(offthegrid|otg) id (.*)$/i, (msg) ->
    location = msg.match[2].trim()

    getLocationMetadataFromUser msg, location, (metadata) =>
      return msg.send "Sorry, I couldn't find an Off the Grid location for: #{location}" if !metadata
      return msg.send "The internal ID for #{metadata.name} is #{metadata.id}."

  ###
  ## Pulls today's hours and vendors for either a given location, or the one configured.
  ###
  robot.respond /(offthegrid|otg)(.*)?$/i, (msg) ->
    if !msg.match[2] && typeof process.env.HUBOT_OFF_THE_GRID_LOCATION_ID == 'undefined'
      return msg.send "Sorry, you neither supplied a location or have set a default."
    else if msg.match[2]
      location = msg.match[2].toLowerCase().trim()
      if location.match(/(id|list)/i)
        return

      getLocationMetadataFromUser msg, location, (metadata) =>
        return msg.send "Sorry, I couldn't find an Off the Grid location for: #{location}" if !metadata

        getLocationHoursAndVendors msg, metadata, (data) =>
          displayLocationData(msg, metadata, data.hours, data.events)
    else
      location = process.env.HUBOT_OFF_THE_GRID_LOCATION_ID
      getLocationMetadataById msg, location, (metadata) =>
        return msg.send "Sorry, I couldn't find an Off the Grid location for the configured default: #{location}" if !metadata

        getLocationHoursAndVendors msg, metadata, (data) =>
          displayLocationData(msg, metadata, data.hours, data.events)


displayLocationData = (msg, metadata, hours, events) ->
  emit = "#{metadata.name}\n"
  emit += "Map: https://www.google.com/maps/search/#{metadata.latitude},#{metadata.longitude}\n"
  emit += "Current Status: #{getLocationStatus(metadata.status)}\n"

  if (hours)
    displayHours = []
    emit += "Hours:\n"
    for day of hours
      displayHours.push(" · #{day}: #{hours[day]}")

    emit += displayHours.join("\n")

  if (hours && events)
    emit += "\n\n"

  if (events)
    emit += "–– Lineup ––\n"
    for event of events
      displayVendors = []
      emit += "#{event}\n"
      if !events[event]
        emit += " · No known vendors yet!\n"
      else
        for vendor in events[event]
          if vendor.url
            displayVendors.push(" · #{vendor.name}: #{vendor.url}")
          else
            displayVendors.push(" · #{vendor.name}")

        emit += displayVendors.join("\n")
        emit += "\n"

  msg.send emit

getLocationHoursAndVendors = (msg, location, cb) ->
  options.url = "http://offthegridsf.com/wp-admin/admin-ajax.php?action=otg_market&market=#{location.id}"

  request options, (err, res, body) =>
    return msg.send "Sorry, Off the Grid doesn't like you. ERROR:#{err}" if err
    return msg.send "Unable to get hours and vendors for #{location.name}: #{res.statusCode}" if res.statusCode != 200

    $ = cheerio.load(body)

    hours = vendors = false

    if $('.otg-market-data-events-event').length > 0
      hours = []
      for event in $('.otg-market-data-events-event')
        day = $(event).find('.otg-market-data-events-event-day').text().toLowerCase().replace(/\./, '')
        time = $(event).find('.otg-market-data-events-event-hours').text()
        ampm = $(event).find('.otg-market-data-events-event-ampm').text()

        day = moment().day(day).format('dddd')

        hours[day] = "#{time}#{ampm}"

    if $('.otg-market-data-events-pagination').length > 0
      events = {}
      for event in $('.otg-market-data-events-pagination')
        eventDateSplit = $(event).text().trim().split('.')
        month = eventDateSplit[0]
        if month[0] == '0'
          month = month[1]

        eventDate = {
          month: month,
          day: eventDateSplit[1]
        }

        # See if the upcoming event is next year
        if eventDate.month < today.month
          eventDate.year = moment().add('y', 1).format('YYYY')
        else
          eventDate.year = today.year

        eventDate.display = moment([eventDate.year, (eventDate.month - 1), eventDate.day]).format('dddd, M/D/YYYY')

        currentEvent = $(event).next()
        if currentEvent.find('.otg-markets-data-vendor-name').length == 0
          events[eventDate.display] = false
        else
          events[eventDate.display] = []
          for vendor in currentEvent.find('.otg-markets-data-vendor-name')
            vendor = $(vendor)

            if (vendor.find('.otg-markets-data-vendor-name-link').length > 0)
              url = vendor.find('.otg-markets-data-vendor-name-link').attr('href')
              if url == ''
                url = false
            else
              url = false

            events[eventDate.display].push({
              name: vendor.text().trim()
              url: url
            })

    return cb({
      hours: hours,
      events: events
    })

getLocations = (msg, cb) ->
  options.url = 'http://offthegridsf.com/markets'

  request options, (err, res, body) =>
    return msg.send "Sorry, Off the Grid doesn't like you. ERROR:#{err}" if err
    return msg.send "Unable to get available locations: #{res.statusCode}" if res.statusCode != 200

    $ = cheerio.load(body)

    locations = $('div.otg-markets-map-container').next().next().text()

    # Tried doing this with lookahead regex instead, but it was giving up an "invalid group" error.
    # Submit a pull request if you have a better method than this failing regex: /(?<=var OTGMarketsJson = ')(.*)/i
    locations = locations.replace(/var OTGMarketsJson = '/, '')
    locations = locations.replace(/';/, '')
    locations = locations.replace(/\\'/g, '\'')
    locations = JSON.parse(locations)

    sorted = []
    for i of locations
      # Some locations, like Lake Merritt, have trailing spaces in their code.
      locations[i].name = locations[i].name.trim()

      sorted.push(locations[i])

    sorted.sort (a, b) ->
      if a.name > b.name
        return 1
      if a.name < b.name
        return -1
      return 0

    cb(sorted)

getLocationMetadataById = (msg, locationId, cb) ->
  getLocations msg, (locations) =>
    for i of locations
      if locations[i].id == locationId
        return cb(locations[i])

    return cb(false)

getLocationMetadataFromUser = (msg, location, cb) ->
  getLocations msg, (locations) =>
    for i of locations
      if locations[i].name.toLowerCase().trim() == location.toLowerCase().trim()
        return cb(locations[i])

    return cb(false)

getLocationStatus = (status) ->
  status = status.toLowerCase()
  if status == 'closed'
    return 'Closed'
  else if status == 'opentoday'
    return 'Open Today'
  else if status == 'opennow'
    return 'Open Now'
