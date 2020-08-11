PROJECT_NAME := cloudrun-rails-study
IMAGE_NAME := cloudrun-rails-study
SERVICE_NAME := cloudrun-rails-study
CLOUD_SQL_INSTANCE_NAME := cloudrun-rails-study
SERVICE_ACCOUNT_EMAIL := cloud-run@cloudrun-rails-study.iam.gserviceaccount.com
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
	gcloud iam service-accounts create cloud-run --display-name "Cloud Run Service Account"
	# サービスアカウントに権限を付与（プロジェクトレベルで）
	gcloud projects add-iam-policy-binding ${PROJECT_NAME} --member serviceAccount:${SERVICE_ACCOUNT_EMAIL} --role roles/editor
	gcloud projects add-iam-policy-binding ${PROJECT_NAME} --member=serviceAccount:${SERVICE_ACCOUNT_EMAIL} --role=roles/run.invoker
	gcloud projects add-iam-policy-binding ${PROJECT_NAME} --member=serviceAccount:${SERVICE_ACCOUNT_EMAIL} --role=roles/errorreporting.writer
	# Cloud SQL Proxy用のサービスアカウントを作成
	gcloud --project=${PROJECT_NAME} iam service-accounts create cloud-sql-proxy --display-name "Cloud SQL Proxy Service Account"
	gcloud --project=${PROJECT_NAME} iam service-accounts keys create ./keys/cloud-sql-proxy.json --iam-account=cloud-sql-proxy@cloudrun-rails-study.iam.gserviceaccount.com
	gcloud projects add-iam-policy-binding ${PROJECT_NAME} --member=serviceAccount:cloud-sql-proxy@cloudrun-rails-study.iam.gserviceaccount.com --role=roles/cloudsql.client
	gcloud projects add-iam-policy-binding ${PROJECT_NAME} --member=serviceAccount:cloud-sql-proxy@cloudrun-rails-study.iam.gserviceaccount.com --role=roles/cloudsql.admin
	gcloud projects add-iam-policy-binding ${PROJECT_NAME} --member=serviceAccount:cloud-sql-proxy@cloudrun-rails-study.iam.gserviceaccount.com --role=roles/cloudsql.editor

# 初回の一度だけ利用
.PHONY: gcloud-db-setup
gcloud-db-setup:
	gcloud --project=${PROJECT_NAME} sql databases create app_production --instance cloudrun-rails-study

.PHONY: gcloud-run-setenv
gcloud-run-setenv:
	gcloud run services update ${SERVICE_NAME} \
		--update-env-vars RAILS_MASTER_KEY=${RAILS_MASTER_KEY} \
		--update-env-vars DATABASE_USERNAME=root \
		--update-env-vars DATABASE_PASSWORD=password \
		--update-env-vars DATABASE_HOST=127.0.0.1
		# --update-env-vars DATABASE_HOST=/cloudsql/${PROJECT_NAME}:asia-northeast1:${CLOUD_SQL_INSTANCE_NAME}
	# arr=($$(cat .env)); \
	# str="$$(IFS=,; echo "$${arr[*]}")"; \
	# gcloud run services update ${SERVICE_NAME} --update-env-vars RACK_ENV=production,$${str}

.PHONY: gcloud-builds-submit
gcloud-builds-submit:
	# gcloud builds submit --tag gcr.io/${PROJECT_NAME}/${IMAGE_NAME}
	gcloud builds submit --substitutions=_RAILS_MASTER_KEY=${RAILS_MASTER_KEY}

.PHONY: gcloud-run-deploy
gcloud-run-deploy:
	gcloud run deploy ${SERVICE_NAME} \
		--image gcr.io/${PROJECT_NAME}/${IMAGE_NAME} \
		--service-account ${SERVICE_ACCOUNT_EMAIL} \
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
