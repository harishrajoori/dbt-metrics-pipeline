localdev-up:
	aws ecr get-login-password --region eu-west-1 | docker login --username AWS --password-stdin 164810850900.dkr.ecr.eu-west-1.amazonaws.com && \
	docker-compose -f ./docker/docker-compose-local.yml up

localdev-down:
	docker-compose -f ./docker/docker-compose-local.yml down

localdev-update:
	aws ecr get-login-password --region eu-west-1 | docker login --username AWS --password-stdin 164810850900.dkr.ecr.eu-west-1.amazonaws.com && \
	docker build -t 164810850900.dkr.ecr.eu-west-1.amazonaws.com/de-sense-localdev:mwaa-localdev-2_7_2 ./docker && \
	docker push 164810850900.dkr.ecr.eu-west-1.amazonaws.com/de-sense-localdev:mwaa-localdev-2_7_2

localdevmodel-requirements:
	pip install -r requirements-model.txt

.PHONY: localdev-up localdev-down localdev-update localdevmodel-requirements