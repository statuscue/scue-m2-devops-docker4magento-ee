include .env

up: ## Pull and start up containers
	@docker-compose up -d --remove-orphans

down: stop ## Stop containers

start: ## Start containers without updating
	@docker-compose start

stop: ## Stop containers
	@docker-compose stop

# You can optionally pass an argument with the service name to prune single container
#
#    prune mariadb : Prune `mariadb` container and remove its volumes.
#    prune mariadb solr : Prune `mariadb` and `solr` containers and remove their volumes.
prune: ## Remove containers and their volumes
	@echo "Removing containers and volumes for $(PROJECT_NAME)..."
	@docker-compose down -v $(filter-out $@,$(MAKECMDGOALS))

ps: ## List running containers
	@docker ps --filter name='$(PROJECT_NAME)*'

# You can optionally pass an argument with a service name to open a shell on the specified container
shell: ## Access container via shell. Default `php` container.
	@docker exec -ti -e COLUMNS=$(shell tput cols) -e LINES=$(shell tput lines) $(shell docker ps --filter name='$(PROJECT_NAME)_$(or $(filter-out $@,$(MAKECMDGOALS)), 'php')' --format "{{ .ID }}") sh

# You can optinally pass an argument with the service name to limit logs
#
#    logs php : View `php` container logs.
#    logs nginx php : View `nginx` and `php` containers logs.
logs: ## View containers logs
	@docker-compose logs -f $(filter-out $@,$(MAKECMDGOALS))

magento: ## Magento CLI
	@docker exec $(shell docker ps --filter name='^/$(PROJECT_NAME)_php' --format "{{ .ID }}") bin/magento $(filter-out $@,$(MAKECMDGOALS))

n98: ## netz98/n98-magerun2 CLI
	@docker exec $(shell docker ps --filter name='^/$(PROJECT_NAME)_php' --format "{{ .ID }}") n98-magerun2 $(filter-out $@,$(MAKECMDGOALS)) --root-dir=$(MAGENTO_ROOT) --skip-core-commands

pestle: ## Pestle CLI
	@docker exec $(shell docker ps --filter name='^/$(PROJECT_NAME)_php' --format "{{ .ID }}") pestle $(filter-out $@,$(MAKECMDGOALS))

composer: ## Composer CLI
	@docker exec $(shell docker ps --filter name='^/$(PROJECT_NAME)_php' --format "{{ .ID }}") composer --working-dir=/var/www/html $(filter-out $@,$(MAKECMDGOALS))

magento_download: ## Download Magento source via Composer
	@docker exec $(shell docker ps --filter name='^/$(PROJECT_NAME)_php' --format "{{ .ID }}") sh -c "\
		composer config --global http-basic.repo.magento.com $(COMPOSER_MAGENTO_REPO_USERNAME) $(COMPOSER_MAGENTO_REPO_PASSWORD) && \
	    composer create-project --no-interaction --repository=https://repo.magento.com/ magento/project-enterprise-edition=$(MAGENTO_VERSION) ~/magento2 && \
	    cp -a ~/magento2/. /var/www/html/ && \
	    rm -rf ~/magento2"

magento_install: ## Install Magento
	docker exec $(shell docker ps --filter name='^/$(PROJECT_NAME)_php' --format "{{ .ID }}") sh -c "\
		chmod u+x bin/magento && \
		bin/magento setup:install \
			--base-url=http://$(PROJECT_BASE_URL):$(PROJECT_BASE_PORT)/ \
			--db-host=$(DB_HOST) \
			--db-name=$(DB_NAME) \
			--db-user=$(DB_USER) \
			--db-password=$(DB_PASSWORD) \
			--admin-firstname=$(MAGENTO_ADMIN_FIRSTNAME) \
			--admin-lastname=$(MAGENTO_ADMIN_LASTNAME) \
			--admin-email=$(MAGENTO_ADMIN_EMAIL) \
			--admin-user=$(MAGENTO_ADMIN_USER) \
			--admin-password=$(MAGENTO_ADMIN_PASSWORD) \
			--backend-frontname=$(MAGENTO_BACKEND_FRONTNAME) \
			--language=$(MAGENTO_LANGUAGE) \
			--currency=$(MAGENTO_CURRENCY) \
			--timezone=$(MAGENTO_TIMEZONE) \
			--use-rewrites=1 \
			--search-engine=elasticsearch7 \
			--elasticsearch-host=elasticsearch \
			--session-save=redis \
			--session-save-redis-host=redis \
			--session-save-redis-port=6379 \
			--session-save-redis-db=2 \
			--session-save-redis-log-level=7 \
			--cache-backend=redis \
			--cache-backend-redis-server=redis \
			--cache-backend-redis-port=6379 \
			--cache-backend-redis-db=0 && \
		bin/magento config:set dev/image/default_adapter IMAGEMAGICK && \
		bin/magento config:set admin/security/session_lifetime 31536000 && \
		bin/magento config:set admin/security/password_lifetime 0 && \
		bin/magento config:set admin/security/password_is_forced 0 && \
		bin/magento config:set admin/security/use_form_key 0 && \
		bin/magento config:set sales/totals_sort/grand_total 10 && \
		bin/magento config:set sales/totals_sort/subtotal 20 && \
		bin/magento cache:clean config && \
		bin/magento module:disable Magento_TwoFactorAuth && \
		bin/magento cache:flush"

setup_magento_redis_session: ## Setup Redis for session storage
	docker exec $(shell docker ps --filter name='^/$(PROJECT_NAME)_php' --format "{{ .ID }}") sh -c "\
		bin/magento setup:config:set \
			--session-save=redis \
			--session-save-redis-host=redis \
			--session-save-redis-port=6379 \
			--session-save-redis-db=2 \
			--session-save-redis-log-level=7"

setup_magento_redis_default_cache: ## Setup Redis for default cache
	docker exec $(shell docker ps --filter name='^/$(PROJECT_NAME)_php' --format "{{ .ID }}") sh -c "\
		bin/magento setup:config:set \
			--cache-backend=redis \
			--cache-backend-redis-server=redis \
			--cache-backend-redis-port=6379 \
			--cache-backend-redis-db=0"

# Dev
#
# yireo/Yireo_Whoops
# https://github.com/yireo/Yireo_Whoops
#
magento_developer: ## Enable developer mode and install DevTools for Magento 2
	@docker exec $(shell docker ps --filter name='^/$(PROJECT_NAME)_php' --format "{{ .ID }}") sh -c "\
		bin/magento deploy:mode:set developer && \
		composer require --dev yireo/magento2-whoops && \
		bin/magento module:enable Yireo_Whoops && \
		bin/magento setup:upgrade"

# Amasty
#
# https://amasty.com/docs/doku.php?id=magento_2:composer_user_guide
#
magento_module_amasty: ## Install premium Amasty modules
	@docker exec $(shell docker ps --filter name='^/$(PROJECT_NAME)_php' --format "{{ .ID }}") sh -c "\
		composer config --auth http-basic.composer.amasty.com $(COMPOSER_AMASTY_REPO_USERNAME) $(COMPOSER_AMASTY_REPO_PASSWORD) && \
		composer config repositories.amasty composer https://composer.amasty.com/enterprise/ && \
		composer require \
			amasty/module-shopby-premium \
			amasty/module-shop-by-brand-graphql \
			amasty/module-elastic-search \
			amasty/module-elastic-search-graphql \
			amasty/label \
			amasty/product-labels-graphql \
		&& \
		bin/magento module:enable \
			Amasty_Base \
			Amasty_ShopbyBase \
			Amasty_CronScheduleList \
			Amasty_ElasticSearch \
			Amasty_Xsearch \
			Amasty_Shopby \
			Amasty_Label \
			Amasty_LabelGraphQl \
			Amasty_Mage24Fix \
			Amasty_Scroll \
			Amasty_ShopByQuickConfig \
			Amasty_ShopbyBrand \
			Amasty_CPS \
			Amasty_ShopbySeo \
			Amasty_ShopbyBrandGraphQl \
			Amasty_ShopbyPage \
			Amasty_GroupedOptions \
			Amasty_VisualMerchUi \
			Amasty_ElasticSearchGraphQl \
		&& \
		bin/magento setup:upgrade"

# DevTools by MageSpecialist
# 
# https://github.com/magespecialist/mage-chrome-toolbar
# https://github.com/magespecialist/m2-MSP_DevTools
#
magento_module_msp_devtools: ## Install DevTools by MageSpecialist
	@docker exec $(shell docker ps --filter name='^/$(PROJECT_NAME)_php' --format "{{ .ID }}") sh -c "\
		composer require msp/devtools && \
		bin/magento config:set msp_devtools/general/enabled 1 && \
        bin/magento config:set msp_devtools/phpstorm/enabled 1 && \
		bin/magento setup:upgrade"

project: ## Setup project
	git clone git@github.com:statuscue/scue-m2-module-liqpay.git app/code/Scue/LiqPay
	git clone git@github.com:statuscue/scue-m2-module-menu.git app/code/Scue/Menu
	git clone git@github.com:statuscue/scue-m2-module-migration.git app/code/Scue/Migration
	git clone git@github.com:statuscue/scue-m2-module-novaposhta.git app/code/Scue/Novaposhta
	git clone git@github.com:statuscue/scue-m2-module-theme.git app/code/Scue/Theme
	git clone git@github.com:statuscue/scue-m2-theme-magento.git app/design/frontend/Scue/magento
	@docker exec $(shell docker ps --filter name='^/$(PROJECT_NAME)_php' --format "{{ .ID }}") sh -c "\
		bin/magento module:enable \
			Scue_LiqPay \
			Scue_Menu \
			Scue_Migration \
			Scue_Novaposhta \
			Scue_Theme \
			--clear-static-content \
		&& \
		bin/magento module:disable \
			Magento_AdobeIms \
			Magento_AdobeImsApi \
			Magento_AdobeStockAdminUi \
			Magento_AdobeStockAssetApi \
			Magento_AdobeStockClient \
			Magento_AdobeStockClientApi \
			Magento_AdobeStockImage \
			Magento_AdobeStockImageApi \
			Magento_AdobeStockAsset \
			Magento_AdobeStockImageAdminUi \
			Amazon_Core \
			Amazon_Login \
			Amazon_Payment \
			Klarna_Core \
			Klarna_Ordermanagement \
			Klarna_Kp \
			Klarna_Onsitemessaging \
			Klarna_KpGraphQl \
			Dotdigitalgroup_Email \
			Dotdigitalgroup_Chat \
			Dotdigitalgroup_Enterprise \
			Dotdigitalgroup_Sms \
			Vertex_Tax \
			Vertex_AddressValidationApi \
			Vertex_AddressValidation \
			Vertex_TaxStaging \
			Magento_Paypal \
			Magento_PaypalGraphQl \
			Magento_PaypalCaptcha \
			PayPal_Braintree \
			PayPal_BraintreeGraphQl \
			Magento_Dhl \
			Magento_Fedex \
			Magento_Ups \
			Magento_Usps \
			Yotpo_Yotpo \
			Temando_ShippingRemover \
			Magento_Weee \
			Magento_WeeeGraphQl \
			Magento_WeeeStaging \
			Magento_Multishipping \
			Magento_DataServicesMultishipping \
			--clear-static-content \
		&& \
		bin/magento setup:upgrade"

.PHONY: up down start stop prune ps shell logs magento n98 pestle composer project

.DEFAULT_GOAL := help
help: ## Print this help
	@grep -E '(^[0-9a-zA-Z_-]+:.*?##.*$$)|(^##)' $(MAKEFILE_LIST) \
		| sed -e 's/^.*Makefile://g' \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "\033[32m%-30s\033[0m %s\n", $$1, $$2}' \
		| sed -e 's/\[32m##/[33m/'
.PHONY: help

# https://stackoverflow.com/a/6273809/1826109
%:
	@:
