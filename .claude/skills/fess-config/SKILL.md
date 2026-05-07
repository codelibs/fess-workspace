---
name: fess-config
description: Use when editing Fess configuration in fess_config.properties or system settings.
---

# Fess Configuration Manager

This skill helps you manage Fess configuration, including application properties, system settings, and environment-specific configurations.

## When to Use

- Adding new configuration properties
- Modifying existing settings
- Setting up environment-specific configurations
- Understanding configuration hierarchy
- Documenting configuration options

## Configuration File Structure

```
repos/fess/src/main/resources/
├── fess_config.properties         # Main application config
├── fess_env*.properties           # Environment-specific overrides
├── fess_indices/                  # OpenSearch index settings
├── app.xml                        # LastaFlute app config
├── env.xml                        # Environment settings
└── mail/                          # Email templates
```

## Workflow

### 1. Understanding Configuration Hierarchy

Fess loads configuration in this order (later overrides earlier):
1. Default values in code
2. `fess_config.properties`
3. `fess_env.properties` (environment-specific)
4. System properties (`-D` flags)
5. Environment variables

### 2. Adding a New Configuration Property

#### Step 1: Define in fess_config.properties
```properties
# Description of the new property
# Default: default_value
my.new.feature.enabled=true
my.new.feature.timeout=30000
```

#### Step 2: Create Config Class Access
```java
// In FessConfig.java or extend it
public interface FessConfig {
    String MY_NEW_FEATURE_ENABLED = "my.new.feature.enabled";
    String MY_NEW_FEATURE_TIMEOUT = "my.new.feature.timeout";

    default boolean isMyNewFeatureEnabled() {
        return getAsBoolean(MY_NEW_FEATURE_ENABLED, true);
    }

    default int getMyNewFeatureTimeout() {
        return getAsInteger(MY_NEW_FEATURE_TIMEOUT, 30000);
    }
}
```

#### Step 3: Use in Application Code
```java
@Resource
private FessConfig fessConfig;

public void doSomething() {
    if (fessConfig.isMyNewFeatureEnabled()) {
        int timeout = fessConfig.getMyNewFeatureTimeout();
        // Implementation
    }
}
```

### 3. Common Configuration Sections

#### Search Settings
```properties
# Search result settings
search.result.size=20
search.result.window.size=10000
search.result.collapsed.max.docs=2
search.result.highlight.enabled=true
```

#### Crawler Settings
```properties
# Crawler configuration
crawler.web.thread.count=3
crawler.web.interval.time=3000
crawler.file.thread.count=2
crawler.data.thread.count=2
```

#### OpenSearch Settings
```properties
# OpenSearch connection
opensearch.cluster.name=fess
opensearch.hosts=localhost:9201
opensearch.username=
opensearch.password=
```

#### Authentication Settings
```properties
# LDAP authentication
ldap.host=ldap://localhost:389
ldap.base.dn=dc=example,dc=com
ldap.bind.dn=cn=admin,dc=example,dc=com
```

#### Logging Settings
```properties
# Log levels
log.level.app=INFO
log.level.crawler=INFO
log.level.suggest=INFO
```

### 4. Environment-Specific Configuration

Create environment-specific files:

```properties
# fess_env_production.properties
opensearch.hosts=es-cluster.internal:9200
log.level.app=WARN

# fess_env_development.properties
opensearch.hosts=localhost:9201
log.level.app=DEBUG
```

Activate with system property:
```bash
java -Dfess.env=production -jar fess.jar
```

### 5. Sensitive Configuration

For passwords and secrets:
```properties
# Use environment variables
opensearch.password=${OPENSEARCH_PASSWORD}

# Or use encrypted values
ldap.bind.password={cipher}encrypted_value_here
```

## Configuration Naming Conventions

| Prefix | Purpose | Example |
|--------|---------|---------|
| `crawler.` | Crawler settings | `crawler.web.thread.count` |
| `search.` | Search behavior | `search.result.size` |
| `index.` | Index settings | `index.document.max.size` |
| `opensearch.` | OpenSearch connection | `opensearch.hosts` |
| `ldap.` | LDAP authentication | `ldap.host` |
| `smtp.` | Email settings | `smtp.host` |
| `api.` | API settings | `api.access.token.length` |
| `admin.` | Admin console | `admin.default.page.size` |

## Best Practices

### Documentation
- Always comment each property with its purpose
- Document valid values and default
- Group related properties together

### Validation
- Validate configuration at startup
- Provide clear error messages for invalid values
- Use reasonable defaults

### Security
- Never commit passwords or secrets
- Use environment variables for sensitive data
- Document which properties are sensitive

### Compatibility
- Use backward-compatible property names
- Mark deprecated properties clearly
- Provide migration notes for breaking changes

## Verification

After modifying configuration:

1. **Check syntax**: No duplicate keys, proper escaping
2. **Verify defaults**: Appropriate for production
3. **Test override**: Environment-specific files work
4. **Check startup**: Application starts without errors
5. **Verify behavior**: Feature works as expected

```bash
# Check for duplicate keys
sort fess_config.properties | uniq -d

# Test configuration loading
java -jar fess.jar --dry-run
```

## Output

When adding or modifying configuration, provide:
1. The property entries with documentation comments
2. The FessConfig interface additions (if needed)
3. Example usage in application code
4. Environment-specific considerations
5. Security implications if applicable
