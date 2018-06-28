# shp2json -n build/cb_2017_us_county_5m.shp -o cb_2017_us_county_5m.ndjson

# shp2json build/cb_2017_us_county_5m.shp -o cb_2017_us_county_5m.json

mkdir -p build test

if [ ! -f build/cb_2017_us_county_5m.shp ]; then
  curl -o build/cb_2017_us_county_5m.zip 'https://www2.census.gov/geo/tiger/GENZ2017/shp/cb_2017_us_county_5m.zip'
  unzip -od build build/cb_2017_us_county_5m.zip cb_2017_us_county_5m.shp cb_2017_us_county_5m.dbf
  chmod a-x build/cb_2017_us_county_5m.*
fi

threshold=0.25

geo2topo -q 1e5 -n counties=<( \
    shp2json -n build/cb_2017_us_county_5m.shp \
      | ndjson-filter '!/000$/.test(d.properties.GEOID)' \
      | ndjson-map '(d.id = d.properties.GEOID, d)' \
      | geostitch -n) \
  | toposimplify -f -s $threshold \
  | topomerge states=counties -k 'd.id.slice(0, 2)' \
  | topomerge nation=states \
  > test/10m-$threshold.json