.PHONY: run
run:
	docker-compose up

.PHONY: downv
downv:
	docker-compose down -v --remove-orphans

.PHONY: zip
unzip:
	zip wine-data.zip winemag-data_first150k.csv

.PHONY: unzip
	unzip wine-data.zip
