.PHONY: run
run:
	docker-compose up

.PHONY: downv
downv:
	docker-compose down -v --remove-orphans

.PHONY: zip
zip:
	zip pgdata/wine-data.zip pgdata/winemag-data_first150k.csv

.PHONY: unzip
unzip:
	unzip pgdata/wine-data.zip -d pgdata

.PHONY: clean
clean:
	rm pgdata/winemag-data_first150k.csv
