# Source-of-Truth Mapping

Map each doc file to its primary source reference.

| Doc Topic | Primary Source |
|-----------|---------------|
| Core config properties | `repos/fess/src/main/resources/fess_config.properties` |
| Config constants/defaults | `repos/fess/src/main/java/org/codelibs/fess/mylasta/direction/FessConfig.java` |
| Application constants | `repos/fess/src/main/java/org/codelibs/fess/Constants.java` |
| SSO (SAML) | `repos/fess/src/main/java/org/codelibs/fess/sso/saml/SamlAuthenticator.java`, `SamlCredential.java` (attribute mapping), `FessProp.java` (permission/behavior properties) |
| SSO (OIDC) | `repos/fess/src/main/java/org/codelibs/fess/sso/oic/OpenIdConnectAuthenticator.java`, `repos/fess/src/main/java/org/codelibs/fess/app/web/base/login/OpenIdConnectCredential.java` (user ID/groups/roles extraction), `FessProp.java` (permission/behavior properties) |
| SSO (Entra ID) | `repos/fess/src/main/java/org/codelibs/fess/sso/entraid/EntraIdAuthenticator.java`, `FessProp.java` (permission/behavior properties e.g. `entraid.permission.fields`, `entraid.use.ds`) |
| SSO (SPNEGO) | `repos/fess/src/main/java/org/codelibs/fess/sso/spnego/SpnegoAuthenticator.java`, `FessProp.java` (permission/behavior properties) |
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
