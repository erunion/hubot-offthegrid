## hubot-offthegrid [![NPM version](https://badge.fury.io/js/hubot-offthegrid.png)](http://badge.fury.io/js/hubot-offthegrid)

The ultimate [Off the Grid](http://offthegridsf.com/) [Hubot](https://github.com/github/hubot) companion.

### Usage

    hubot offthegrid list - Pulls a list of all Off the Grid locations
    hubot offthegrid <location name> - Pulls today's hours and vendors for a given location
    hubot offthegrid - Pulls today's hours and vendors for the configured location

![hubot offthegrid](https://raw.githubusercontent.com/jonursenbach/hubot-offthegrid/master/img/usage.png)

#### Configuration

If you don't want to supply a location to `hubot offthegrid` every time, you can set up a default location. To do this, you'll need to get the name of the location you want to default to via `hubot offthegrid list`

![hubot offthegrid list](https://raw.githubusercontent.com/jonursenbach/hubot-offthegrid/master/img/list.png)

Then supply that location name to `hubot offthegrid id`.

![hubot offthegrid id](https://raw.githubusercontent.com/jonursenbach/hubot-offthegrid/master/img/location-id.png)

Once you have that internal ID, set it to the `HUBOT_OFF_THE_GRID_LOCATION_ID` environment variable.

##### Heroku

    % heroku config:add HUBOT_OFF_THE_GRID_LOCATION_ID="38"

##### Non-Heroku environment variables

    % export HUBOT_OFF_THE_GRID_LOCATION_ID="38"

### Installation
1. Edit `package.json` and add `hubot-offthegrid` as a dependency.
2. Add `"hubot-offthegrid"` to your `external-scripts.json` file.
3. `npm install`
4. Reboot Hubot.
5. Get hungry.
