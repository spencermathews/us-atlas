#!/bin/bash

mkdir -p build

# Downloads state FIPS codes
if [ ! -f build/state.txt ]; then
  curl -z build/state.txt -o build/state.txt https://www2.census.gov/geo/docs/reference/state.txt
  # curl -z build/national_county.txt -o build/national_county.txt https://www2.census.gov/geo/docs/reference/codes/files/national_county.txt
  # chmod a-x build/*.txt
fi

# Generates counties.ndjson
# Feature id is poplulated from GEOID property.
# Properties: name, STATEFP
shp2json -n build/cb_2017_us_county_5m.shp \
  | ndjson-filter '!/000$/.test(d.properties.GEOID)' \
  | ndjson-map '(d.id = d.properties.GEOID, name = d.properties.NAME, STATEFP = d.properties.STATEFP, d.properties = {}, d.properties.name = name, d.properties.STATEFP = STATEFP, d)' \
  >| build/counties.ndjson

# Generates counties.topojson.
# Adds STATE_NAME and STUSAB (~STUSPS) by joining on state FIPS code.
# Removes extra properties: STATE is redundant with STATEFP, STATENS is unnecessary. 
ndjson-join --left 'd.properties.STATEFP' 'd.STATE' \
    build/counties.ndjson \
    <(dsv2json -r "|" -n build/state.txt) \
  | ndjson-map 'Object.assign(d[0].properties, d[1]), delete d[0].properties.STATE, delete d[0].properties.STATENS, d[0]' \
  | ndjson-reduce 'p.features.push(d), p' '{type: "FeatureCollection", features: []}' >| build/counties.geojson
geo2topo build/counties.geojson >| build/counties.topojson

# Merges counties into states using state FIPS as key.
# 
cat build/counties.topojson \
  | topomerge states=counties -k 'd.id.slice(0, 2)' \
  | topomerge nation=states \
  >| build/states.topojson

