PROJECT_NAME := cloudrun-rails-study
IMAGE_NAME := cloudrun-rails-study
SERVICE_NAME := cloudrun-rails-study
CLOUD_SQL_INSTANCE_NAME := cloudrun-rails-study
CLOUD_RUN_SERVICE_ACCOUNT_EMAIL=cloud-run@${PROJECT_NAME}.iam.gserviceaccount.com
CLOUD_SQL_PROXY_SERVICE_ACCOUNT_EMAIL=cloud-sql-proxy@${PROJECT_NAME}.iam.gserviceaccount.com
RAILS_MASTER_KEY := $(shell cat config/master.key)

.PHONY: gcloud-setup
gcloud-setup:
	# gcloud config configurations list
	# gcloud config list
	# gcloud projects list
	gcloud config configurations activate default
	gcloud auth login
	gcloud config set project ${PROJECT_NAME}
	gcloud config set run/platform managed
	gcloud config set run/region asia-northeast1

# プロジェクトのiamポリシーを確認
.PHONY: gcloud-iam-check
gcloud-iam-check:
	gcloud projects get-iam-policy ${PROJECT_NAME}

# 初回の一度だけ利用
.PHONY: gcloud-iam-setup
gcloud-iam-setup:
	# Cloud Run用のサービスアカウントを作成
	gcloud --project=${PROJECT_NAME} iam service-accounts create cloud-run --display-name "Cloud Run Service Account"
	gcloud projects add-iam-policy-binding ${PROJECT_NAME} --member serviceAccount:${CLOUD_RUN_SERVICE_ACCOUNT_EMAIL} --role roles/editor
	gcloud projects add-iam-policy-binding ${PROJECT_NAME} --member=serviceAccount:${CLOUD_RUN_SERVICE_ACCOUNT_EMAIL} --role=roles/run.invoker
	gcloud projects add-iam-policy-binding ${PROJECT_NAME} --member=serviceAccount:${CLOUD_RUN_SERVICE_ACCOUNT_EMAIL} --role=roles/errorreporting.writer
	# Cloud SQL Proxy用のサービスアカウントを作成
	gcloud --project=${PROJECT_NAME} iam service-accounts create cloud-sql-proxy --display-name "Cloud SQL Proxy Service Account"
	gcloud --project=${PROJECT_NAME} iam service-accounts keys create ./keys/cloud-sql-proxy.json --iam-account=${CLOUD_SQL_PROXY_SERVICE_ACCOUNT_EMAIL}
	gcloud projects add-iam-policy-binding ${PROJECT_NAME} --member=serviceAccount:${CLOUD_SQL_PROXY_SERVICE_ACCOUNT_EMAIL} --role=roles/cloudsql.client
	gcloud projects add-iam-policy-binding ${PROJECT_NAME} --member=serviceAccount:${CLOUD_SQL_PROXY_SERVICE_ACCOUNT_EMAIL} --role=roles/cloudsql.admin
	gcloud projects add-iam-policy-binding ${PROJECT_NAME} --member=serviceAccount:${CLOUD_SQL_PROXY_SERVICE_ACCOUNT_EMAIL} --role=roles/cloudsql.editor

# 初回の一度だけ利用
.PHONY: gcloud-db-setup
gcloud-db-setup:
	gcloud sql instances create ${CLOUD_SQL_INSTANCE_NAME} \
		--project=${PROJECT_NAME} \
		--region asia-northeast1 \
		--assign-ip \
		--tier db-f1-micro \
		--root-password=$${DB_ROOT_PASSWORD}
	gcloud sql users create app \
		--project=${PROJECT_NAME} \
		--instance=${CLOUD_SQL_INSTANCE_NAME} \
		--password=$${DB_APP_PASSWORD}
	# gcloud --project=${PROJECT_NAME} sql databases create app_production --instance ${CLOUD_SQL_INSTANCE_NAME}

# .PHONY: gcloud-db-destroy
# gcloud-db-destroy:
# 	gcloud sql instances delete ${CLOUD_SQL_INSTANCE_NAME} --project=${PROJECT_NAME}

.PHONY: gcloud-run-setenv
gcloud-run-setenv:
	gcloud run services update ${SERVICE_NAME} \
		--project=${PROJECT_NAME} \
		--update-env-vars RAILS_MASTER_KEY=${RAILS_MASTER_KEY} \
		--update-env-vars DATABASE_USERNAME=app \
		--update-env-vars DATABASE_PASSWORD=password \
		--update-env-vars DATABASE_SOCKET=/cloudsql/${PROJECT_NAME}:asia-northeast1:${CLOUD_SQL_INSTANCE_NAME}
		# --update-env-vars DATABASE_HOST=127.0.0.1
	# arr=($$(cat .env)); \
	# str="$$(IFS=,; echo "$${arr[*]}")"; \
	# gcloud run services update ${SERVICE_NAME} --update-env-vars RACK_ENV=production,$${str}

.PHONY: gcloud-builds-submit
gcloud-builds-submit:
	gcloud builds submit --project=${PROJECT_NAME} --tag gcr.io/${PROJECT_NAME}/${IMAGE_NAME}

.PHONY: gcloud-builds-submit-with-cloudbuild
gcloud-builds-submit-with-cloudbuild:
	gcloud builds submit --project=${PROJECT_NAME} --substitutions=_RAILS_MASTER_KEY=${RAILS_MASTER_KEY}

.PHONY: gcloud-run-deploy
gcloud-run-deploy:
	gcloud run deploy ${SERVICE_NAME} \
		--project=${PROJECT_NAME} \
		--image gcr.io/${PROJECT_NAME}/${IMAGE_NAME} \
		--service-account ${CLOUD_RUN_SERVICE_ACCOUNT_EMAIL} \
		--platform managed \
		--region asia-northeast1 \
		--add-cloudsql-instances ${PROJECT_NAME}:asia-northeast1:${CLOUD_SQL_INSTANCE_NAME}

.PHONY: gcloud-build-and-deploy
gcloud-build-and-deploy:
	make gcloud-builds-submit
	make gcloud-run-deploy

.PHONY: docker-build-as-prod
docker-build-as-prod:
	docker image build --build-arg RAILS_MASTER_KEY=${RAILS_MASTER_KEY} --tag cloudrun-rails-study_prod .

.PHONY: docker-run-as-prod
docker-run-as-prod:
	docker container run --rm --env RAILS_MASTER_KEY=${RAILS_MASTER_KEY} cloudrun-rails-study_prod

.PHONY: rails-setup
rails-setup:
	docker-compose run --rm app sh -c 'rails db:setup && rails db:seed'

.PHONY: db-console-prod
db-console-prod:
	docker-compose up -d cloud_sql_proxy
	mysql -uroot -h0.0.0.0 -P${CLOUD_SQL_PROXY_PORT:-3306} -p
