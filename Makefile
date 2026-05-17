.PHONY: build up down shell logs lint test

build:
	docker-compose build

up:
	docker-compose up --build

down:
	docker-compose down

shell:
	docker-compose exec web /bin/bash

logs:
	docker-compose logs -f

lint:
	pip install flake8 && flake8 .

test:
	pip install pytest && pytest -q
