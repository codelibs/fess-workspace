# Source-of-Truth Mapping

Map each doc file to its primary source reference.

15.9 moved the four SSO authenticators into `fess-sso-*` repositories and the S3/GCS storage clients
into `fess-storage-*`; the rows below point at those. Reviewing 15.8 or earlier docs, read the same
classes under `repos/fess/src/main/java/org/codelibs/fess/sso/` and `.../storage/` on the `15.8.x`
branch instead.

| Doc Topic | Primary Source |
|-----------|---------------|
| Core config properties | `repos/fess/src/main/resources/fess_config.properties` |
| Config constants/defaults | `repos/fess/src/main/java/org/codelibs/fess/mylasta/direction/FessConfig.java` |
| Application constants | `repos/fess/src/main/java/org/codelibs/fess/Constants.java` |
| SSO (type dispatch, missing plugin) | `repos/fess/src/main/java/org/codelibs/fess/sso/SsoManager.java` — resolves the authenticator as `<sso.type>Authenticator`, maps the legacy `aad` to `entraid`, and warns which plugin to install; `FessProp.java` holds `sso.type` |
| SSO (SAML) | `repos/fess-sso-saml/src/main/java/org/codelibs/fess/sso/saml/SamlAuthenticator.java`, `SamlCredential.java` (attribute mapping); `saml.*` keys come from `WEB-INF/conf/system.properties` |
| SSO (OIDC) | `repos/fess-sso-oidc/src/main/java/org/codelibs/fess/sso/oic/OpenIdConnectAuthenticator.java`, `OpenIdConnectCredential.java` (user ID/groups/roles extraction — the credential moved out of `org.codelibs.fess.app.web.base.login`). The type stays `sso.type=oic` |
| SSO (Entra ID) | `repos/fess-sso-entraid/src/main/java/org/codelibs/fess/sso/entraid/EntraIdAuthenticator.java`, `EntraIdCredential.java`; `FessProp.java` still owns `entraid.permission.fields` and `entraid.use.ds`, each with an `aad.*` fallback |
| SSO (SPNEGO) | `repos/fess-sso-spnego/src/main/java/org/codelibs/fess/sso/spnego/SpnegoAuthenticator.java` — the `SpnegoConfig.getInitParameter()` switch is the authoritative list of `spnego.*` keys and their defaults |
| API endpoints | `repos/fess/src/main/java/org/codelibs/fess/api/` |
| LLM/RAG chat (core) | `repos/fess/src/main/java/org/codelibs/fess/llm/AbstractLlmClient.java` |
| LLM/RAG chat (session/history) | `repos/fess/src/main/java/org/codelibs/fess/chat/ChatClient.java`, `ChatSessionManager.java` |
| LLM/RAG chat (phases) | `repos/fess/src/main/java/org/codelibs/fess/chat/ChatPhaseCallback.java` (phase constant definitions) |
| LLM/RAG chat (API) | `repos/fess/src/main/java/org/codelibs/fess/api/chat/ChatApiManager.java` |
| LLM providers | `repos/fess-llm-ollama/`, `repos/fess-llm-openai/`, `repos/fess-llm-gemini/` |
| LLM prompt types (authoritative list) | Each plugin's `*LlmClient.applyDefaultParams()` switch statement — enumerates all supported prompt types with hardcoded defaults for temperature, max.tokens, thinking.budget |
| LLM plugin configurable properties | Each plugin's `*LlmClient` class — scan all `getConfigInt()`, `getConfigLong()`, and `getOrDefault(getConfigPrefix() + ".*")` calls to find every configurable property key and its default value. Also check `AbstractLlmClient` for inherited properties (e.g., `max.concurrent.requests`, `concurrency.wait.timeout`) |
| Crawling | `repos/fess/src/main/java/org/codelibs/fess/crawler/`, `repos/fess-crawler/` |
| Crawler clients (S3) | `repos/fess-crawler/fess-crawler/src/main/java/org/codelibs/fess/crawler/client/s3/S3Client.java` |
| Crawler clients (GCS) | `repos/fess-crawler/fess-crawler/src/main/java/org/codelibs/fess/crawler/client/gcs/GcsClient.java` |
| Crawler clients (Storage) | `repos/fess-crawler/fess-crawler/src/main/java/org/codelibs/fess/crawler/client/storage/StorageClient.java` |
| Storage clients (registry, config) | `repos/fess/src/main/java/org/codelibs/fess/storage/StorageClientFactory.java` — resolves `<storage.type>StorageClient`; `StorageType.java` (endpoint auto-detection), `FessProp.java` (`storage.*` accessors), `AdminStorageAction.java` (admin UI) |
| Storage clients (S3) | `repos/fess-storage-s3/src/main/java/org/codelibs/fess/storage/s3/S3StorageClient.java`; `fess_storage++.xml` registers `s3StorageClient` and `s3_compatStorageClient`, and `crawler/client++.xml` registers the `s3:` crawler client via `S3ClientCreator` |
| Storage clients (GCS) | `repos/fess-storage-gcs/src/main/java/org/codelibs/fess/storage/gcs/GcsStorageClient.java`; `fess_storage++.xml` registers `gcsStorageClient`, and `crawler/client++.xml` registers the `gcs:` crawler client via `GcsClientCreator` |
| Datastore connectors (implementations) | `repos/fess-ds-*/src/main/java/` — each plugin's DataStore subclass(es) |
| Datastore connectors (client/auth params) | `repos/fess-ds-*/src/main/java/` — plugin's `*Client.java` or `*Helper.java` classes (e.g., `Microsoft365Client.java`, `BoxClient.java`) define shared authentication and connection parameters (`proxy_*`, `cache_size`, `max_content_length`, etc.) that are common to all connectors in the plugin but not declared in the DataStore classes |
| Datastore handler registration | `repos/fess-ds-*/src/main/resources/fess_ds++.xml` — `<component>` entries define registered handler names |
| Datastore handler name resolution | Each DataStore class inherits `getName()` from `AbstractDataStore`, returning `getClass().getSimpleName()` — this is the handler name used in admin UI |
| Datastore parameter constants | Each DataStore class's `*_PARAM` static fields — grep `PARAM = "` to find all accepted parameter names |
| Datastore core framework | `repos/fess/src/main/java/org/codelibs/fess/ds/AbstractDataStore.java` (base class, inherited params: `readInterval`), `DataStoreFactory.java` (plugin discovery) |
| Datastore library dependencies | CSV → OrangeSignal CSV (`com.orangesignal.csv`), JSON → Jackson (`com.fasterxml.jackson`), Database → JDBC. Default values for parsing behavior (e.g., escape character, separator) may be delegated to these libraries rather than hardcoded in the plugin. |
| Search/Query | `repos/fess/src/main/java/org/codelibs/fess/helper/SearchHelper.java`, `QueryHelper.java` |
| Geo search (parameters/query) | `repos/fess/src/main/java/org/codelibs/fess/entity/GeoInfo.java` (parameter parsing, geo-distance query construction) |
| Geo search (config) | `fess_config.properties` (`query.geo.fields`), `repos/fess/src/main/java/org/codelibs/fess/query/QueryFieldConfig.java` (sort fields whitelist) |
| Index field mappings | `repos/fess/src/main/resources/fess_indices/fess/doc.json` (standard), `_aws/fess/doc.json`, `_cloud/fess/doc.json` (cloud variants) |
| Scroll Search API | `repos/fess/src/main/java/org/codelibs/fess/api/json/SearchApiManager.java` (`processScrollSearchRequest()`, `JsonRequestParams`), `repos/fess/src/main/java/org/codelibs/fess/query/QueryFieldConfig.java` (`getScrollResponseFields()`) |
| Index mappings | `repos/fess/src/main/resources/fess_indices/` |
| LDAP | `repos/fess/src/main/java/org/codelibs/fess/ldap/` |
| Mail/SMTP settings | `repos/fess/src/main/resources/fess_env.properties` (`mail.smtp.server.main.host.and.port`) |
| DI config | `repos/fess/src/main/resources/app.xml`, `fess.xml`, `fess_*.xml` |
| JVM/Memory/Startup | `repos/fess/src/main/assemblies/files/fess.in.sh`, `fess.in.bat` |
| Windows service setup | `repos/fess/src/main/assemblies/files/service.bat` (FESS_PARAMS, service ID, startup config) |
| Virtual Host | `repos/fess/src/main/java/org/codelibs/fess/helper/VirtualHostHelper.java`, `FessProp.java:getVirtualHosts()` |
| Package env config | `repos/fess/src/packaging/common/env/fess` |
| Admin general settings (SSO, notification, etc.) | `repos/fess/src/main/java/org/codelibs/fess/app/web/admin/general/AdminGeneralAction.java` — all system properties configurable via admin UI; trace `setSystemProperty()` calls to find which properties are UI-configurable |
| Backup/Restore | `repos/fess/src/main/java/org/codelibs/fess/app/web/admin/backup/AdminBackupAction.java`, `fess_config.properties` (`index.backup.targets`, `index.backup.log.targets`) |
| Admin maintenance | `repos/fess/src/main/java/org/codelibs/fess/app/web/admin/maintenance/AdminMaintenanceAction.java` |
| Scripting engine | `repos/fess/src/main/java/org/codelibs/fess/script/groovy/GroovyEngine.java` (Groovy実装), `repos/fess/src/main/java/org/codelibs/fess/script/ScriptEngineFactory.java` (エンジン登録), `repos/fess/src/main/java/org/codelibs/fess/script/ScriptEngine.java` (インターフェース) |
| Scripting job execution | `repos/fess/src/main/java/org/codelibs/fess/job/impl/ScriptExecutor.java` (ジョブ実行・`executor`注入), `repos/fess/src/main/java/org/codelibs/fess/app/job/ScriptExecutorJob.java` (LaJob統合) |
| Scripting DI config | `repos/fess/src/main/resources/fess_se.xml` (ScriptEngineFactory), `repos/fess/src/main/resources/fess_se++.xml` (GroovyEngine登録), `repos/fess/src/main/resources/fess_job.xml` (ScriptExecutor) |
| Scripting usage sites | `repos/fess/src/main/java/org/codelibs/fess/ds/AbstractDataStore.java` (データストア), `repos/fess/src/main/java/org/codelibs/fess/helper/PathMappingHelper.java` (パスマッピング), `repos/fess/src/main/java/org/codelibs/fess/indexer/DocBoostMatcher.java` (ブースト計算), `repos/fess/src/main/java/org/codelibs/fess/crawler/transformer/FessTransformer.java` (クローラ変換) |
| Scheduled jobs | `repos/fess/src/main/resources/fess_indices/fess_config.scheduled_job/scheduled_job.bulk` (job names, default scripts, cron expressions), `repos/fess/src/main/java/org/codelibs/fess/job/` (job classes) |
| Deployment paths | `repos/fess/src/main/assemblies/common-bin.xml`, `repos/fess/src/packaging/rpm/`, `repos/fess/src/packaging/deb/` |
| Runtime path resolution | `repos/fess/src/main/java/org/codelibs/fess/util/ResourceUtil.java` |
| Log file naming | `repos/fess/src/main/java/org/codelibs/fess/job/ExecJob.java` (`getLogName()`), `repos/fess/src/main/webapp/WEB-INF/env/*/resources/log4j2.xml` |
| Rank Fusion | `repos/fess/src/main/java/org/codelibs/fess/rank/fusion/RankFusionProcessor.java`, `fess_config.properties` (`rank.fusion.*`), `fess_rankfusion.xml` (DI config) |
| Crawler config parameters (`client.*`) | `repos/fess/src/main/java/org/codelibs/fess/opensearch/config/exentity/CrawlingConfig.java` (`Param.Client`), `WebConfig.java`, `FileConfig.java` |
