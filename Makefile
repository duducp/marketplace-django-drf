path_project=./src/project

ifneq (,$(wildcard ./.env))
    include .env
    export
else
	export SIMPLE_SETTINGS=project.core.settings.development
	export DJANGO_SETTINGS_MODULE=project.core.settings.development
endif

info:
	@echo "To see the available Django commands, run the following command at the root of the project: python src/manage.py"
	@echo
	@echo "For more information read the project Readme."

clean: ## clean local environment
	@find . -name "*.pyc" | xargs rm -rf
	@find . -name "*.pyo" | xargs rm -rf
	@find . -name "__pycache__" -type d | xargs rm -rf
	@rm -f .coverage
	@rm -rf htmlcov/
	@rm -f coverage.xml
	@rm -f *.log

pre-commit:
	pre-commit install

dependencies: ## install development dependencies
	pip install -U -r src/requirements/dev.txt
	pre-commit install

superuser: ## creates superuser for admin
	python src/manage.py createsuperuser

collectstatic: ## creates static files for admin
	python src/manage.py collectstatic --clear --noinput

app:  ## creates a new django application Ex.: make app name=products
	cd $(path_project) && python ../manage.py startapp --template=../../.template/app_name.zip -e py -e md $(name)
	@echo 'Application created in "$(path_project)/$(name)"'
	@echo 'Read the readme for more details: $(path_project)/$(name)/Readme.md'

run: collectstatic  ## run the django project
	gunicorn -b 0.0.0.0:8000 -t 300 project.core.asgi:application -k uvicorn.workers.UvicornWorker --reload

migrate:  ## apply migrations to the database
	python src/manage.py migrate

migration:  ## creates migration file according to the models
	python src/manage.py makemigrations

migration-empty:  ## creates blank migration file
	python src/manage.py makemigrations --empty $(app)

migration-detect:  ## detect missing migrations
	python src/manage.py makemigrations --dry-run --noinput | grep 'No changes detected' -q || (echo 'Missing migration detected!' && exit 1)

dumpdata:  ## removes all data registered in the database
	python src/manage.py dumpdata

urls:  ## run the django project
	python src/manage.py show_urls

shell:
	python src/manage.py shell_plus --ipython  # shell -i ipython


docker-up:
	docker-compose -f docker-compose.yml up -d --build

docker-down:
	docker-compose -f docker-compose.yml down

docker-downclear:
	docker-compose -f docker-compose.yml down -v


test: clean ## run tests
	pytest -x

test-matching: clean ## run matching tests
	pytest -x -k $(q) --pdb

test-debug: clean ## run tests with pdb
	pytest -x --pdb

test-coverage: clean ## run tests with coverage
	pytest -x --cov=src/project/ --cov-report=term-missing --cov-report=xml

test-coverage-html: clean ## run tests with coverage with html report
	pytest -x --cov=src/project/ --cov-report=html:htmlcov

test-coverage-html-server: test-coverage-html ## run server for view coverage tests
	cd htmlcov && python -m http.server 8001 --bind 0.0.0.0

lint: ## run code lint
	isort .
	sort-requirements src/requirements/base.txt
	sort-requirements src/requirements/prod.txt
	sort-requirements src/requirements/dev.txt
	sort-requirements src/requirements/test.txt
	flake8 --show-source .
	pycodestyle --show-source .
	mypy src/project/

safety-check: ## checks libraries safety
	safety check -r src/requirements/base.txt
	safety check -r src/requirements/prod.txt
	safety check -r src/requirements/dev.txt
	safety check -r src/requirements/test.txt

changelog-feature:  ## signifying a new feature
	@echo $(message) > changelog/$(filename).feature

changelog-bugfix:  ## signifying a bug fix
	@echo $(message) > changelog/$(filename).bugfix

changelog-doc:  ## signifying a documentation improvement
	@echo $(message) > changelog/$(filename).doc

changelog-removal:  ## signifying a deprecation or removal of public API
	@echo $(message) > changelog/$(filename).removal

changelog-misc:  ## a ticket has been closed, but it is not of interest to users
	@echo $(message) > changelog/$(filename).misc

release-draft: ## show new release changelog
	towncrier --draft

release-patch: ## create patch release (0.0.1)
	bumpversion patch --dry-run --no-tag --no-commit --list | grep new_version= | sed -e 's/new_version=//' | xargs -n 1 towncrier --yes --version
	git commit -am 'Update CHANGELOG'
	bumpversion patch
	@echo 'To send the changes to the remote server run the make push command'

release-minor: ## create minor release (0.1.0)
	bumpversion minor --dry-run --no-tag --no-commit --list | grep new_version= | sed -e 's/new_version=//' | xargs -n 1 towncrier --yes --version
	git commit -am 'Update CHANGELOG'
	bumpversion minor
	@echo 'To send the changes to the remote server run the make push command'

release-major: ## create major release (1.0.0)
	bumpversion major --dry-run --no-tag --no-commit --list | grep new_version= | sed -e 's/new_version=//' | xargs -n 1 towncrier --yes --version
	git commit -am 'Update CHANGELOG'
	bumpversion major
	@echo 'To send the changes to the remote server run the make push command'

push:
	git push && git push --tags

.PHONY: clean push test lint app run pre-commit
