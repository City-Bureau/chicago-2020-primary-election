S3_BUCKET = city-bureau-projects
RACES_230 = $(shell cat input/results-metadata.json | jq -r '.["230"].races[] | keys[]' | xargs -I {} echo "output/results/230/{}.csv")
RACES_240 = $(shell cat input/results-metadata.json | jq -r '.["240"].races[] | keys[]' | xargs -I {} echo "output/results/240/{}.csv")
RACES_250 = $(shell cat input/results-metadata.json | jq -r '.["250"].races[] | keys[]' | xargs -I {} echo "output/results/250/{}.csv")

.PHONY: data
data: $(RACES_230) $(RACES_240) $(RACES_250) output/tiles/precincts/

.PHONY: all
all: input/results-metadata.json

.PRECIOUS: input/230/%.html input/240/%.html input/250/%.html

.PHONY: deploy
deploy:
	aws s3 cp ./output/tiles s3://$(S3_BUCKET)/chicago-2020-primary-election/tiles/ --recursive --acl=public-read --content-encoding=gzip --region=us-east-1
	aws s3 cp ./output/results s3://$(S3_BUCKET)/chicago-2020-primary-election/results/ --recursive --acl=public-read --region=us-east-1

output/tiles/precincts/: input/precincts.mbtiles
	mkdir -p output/tiles
	tile-join --no-tile-size-limit --force -e $@ $<

output/results/230/%.csv: input/230/%.html
	mkdir -p $(dir $@)
	pipenv run python scripts/scrape_table.py $< > $@

output/results/240/%.csv: input/240/%.html
	mkdir -p $(dir $@)
	pipenv run python scripts/scrape_table.py $< > $@

output/results/250/%.csv: input/250/%.html
	mkdir -p $(dir $@)
	pipenv run python scripts/scrape_table.py $< > $@

input/230/%.html:
	mkdir -p $(dir $@)
	curl https://chicagoelections.gov/en/election-results-specifics.asp -X POST -H "Content-Type: application/x-www-form-urlencoded" -d "election=230&race=$*&ward=&precinct=" -o $@

input/240/%.html:
	mkdir -p $(dir $@)
	curl https://chicagoelections.gov/en/election-results-specifics.asp -X POST -H "Content-Type: application/x-www-form-urlencoded" -d "election=240&race=$*&ward=&precinct=" -o $@

input/250/%.html:
	mkdir -p $(dir $@)
	curl https://chicagoelections.gov/en/election-results-specifics.asp -X POST -H "Content-Type: application/x-www-form-urlencoded" -d "election=250&race=$*&ward=&precinct=" -o $@

input/230/0.html:
	mkdir -p $(dir $@)
	curl https://chicagoelections.gov/en/election-results-specifics.asp -X POST -H "Content-Type: application/x-www-form-urlencoded" -d "election=230&race=&ward=&precinct=" -o $@

input/240/0.html:
	mkdir -p $(dir $@)
	curl https://chicagoelections.gov/en/election-results-specifics.asp -X POST -H "Content-Type: application/x-www-form-urlencoded" -d "election=240&race=&ward=&precinct=" -o $@

input/250/0.html:
	mkdir -p $(dir $@)
	curl https://chicagoelections.gov/en/election-results-specifics.asp -X POST -H "Content-Type: application/x-www-form-urlencoded" -d "election=250&race=&ward=&precinct=" -o $@

input/results-metadata.json:
	pipenv run python scripts/scrape_results_metadata.py > $@

input/precincts.mbtiles: input/precincts.geojson
	tippecanoe --simplification=10 --simplify-only-low-zooms --maximum-zoom=11 --no-tile-stats --generate-ids \
	--force --detect-shared-borders --coalesce-smallest-as-needed -L precincts:$< -o $@

input/precincts.geojson: input/chi-precincts.geojson input/wards.geojson
	mapshaper -i $< -clip $(filter-out $<,$^) -o $@

input/chi-precincts.geojson: input/raw-chi-precincts.geojson
	cat $< | pipenv run python scripts/create_geojson_id.py > $@

input/raw-chi-precincts.geojson:
	wget -O $@ https://raw.githubusercontent.com/datamade/chicago-municipal-elections/master/precincts/2019_precincts.geojson

input/wards.geojson:
	wget -O $@ 'https://data.cityofchicago.org/api/geospatial/sp34-6z76?method=export&format=GeoJSON'
