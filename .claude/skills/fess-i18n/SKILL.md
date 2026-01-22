---
name: fess-i18n
description: Manage internationalization messages in Fess. Use when adding new user-facing text, translating messages, or managing fess_message*.properties files.
---

# Fess Internationalization (i18n) Manager

This skill helps you manage multi-language support in Fess, including message properties, labels, and validation error messages.

## When to Use

- Adding new user-facing text
- Translating existing messages
- Checking for missing translations
- Managing label consistency
- Working with validation error messages

## Message File Structure

Fess uses Java Properties files for internationalization:

```
repos/fess/src/main/resources/
├── fess_message.properties        # Default (English)
├── fess_message_ja.properties     # Japanese
├── fess_label.properties          # UI labels (English)
├── fess_label_ja.properties       # UI labels (Japanese)
└── fess_config.properties         # Configuration (not i18n)
```

## Workflow

### 1. Adding a New Message

#### Step 1: Define the key in English (default)
```properties
# fess_message.properties
labels.feature_new_title = New Feature
labels.feature_new_description = This is a description of the new feature.
errors.feature_validation = Please enter a valid value for {0}.
```

#### Step 2: Add Japanese translation
```properties
# fess_message_ja.properties
labels.feature_new_title = 新機能
labels.feature_new_description = これは新機能の説明です。
errors.feature_validation = {0}に有効な値を入力してください。
```

### 2. Using Messages in Code

#### In Action Classes (LastaFlute)
```java
// Using messages
String message = messageManager.getMessage("labels.feature_new_title");

// With parameters
String error = messageManager.getMessage("errors.feature_validation", "Name");
```

#### In JSP Views
```jsp
<%-- Using LastaFlute tag --%>
<la:message key="labels.feature_new_title"/>

<%-- With parameters --%>
<la:message key="errors.feature_validation" arg0="${fieldName}"/>
```

#### In Validation
```java
public class MyForm {
    @Required(message = "{errors.required}")
    @Size(max = 100, message = "{errors.max_length}")
    public String name;
}
```

### 3. Message Naming Conventions

Follow Fess's existing patterns:

| Prefix | Usage | Example |
|--------|-------|---------|
| `labels.` | UI labels and titles | `labels.search_button` |
| `errors.` | Validation/error messages | `errors.required` |
| `success.` | Success notifications | `success.saved` |
| `confirm.` | Confirmation dialogs | `confirm.delete` |
| `info.` | Informational messages | `info.no_results` |

### 4. Checking for Missing Translations

Use this checklist:
1. Find all keys in default file
2. Compare with each language file
3. Identify missing keys
4. Add translations or placeholders

```bash
# Compare keys between files
diff <(grep -E "^[a-zA-Z]" fess_message.properties | cut -d= -f1 | sort) \
     <(grep -E "^[a-zA-Z]" fess_message_ja.properties | cut -d= -f1 | sort)
```

### 5. Placeholder Syntax

Use numbered placeholders for dynamic values:

```properties
# Single placeholder
errors.min_length = Must be at least {0} characters.

# Multiple placeholders
errors.range = Value must be between {0} and {1}.
```

## Best Practices

### Consistency
- Use the same key prefix across all language files
- Keep translations in the same order as the default file
- Use consistent terminology throughout

### Clarity
- Write clear, user-friendly messages
- Avoid technical jargon in user-facing text
- Consider cultural differences in translations

### Maintenance
- Comment sections for organization
- Group related messages together
- Remove unused messages periodically

### Parameters
- Use placeholders instead of concatenation
- Order placeholders logically
- Document what each placeholder represents

## Common Patterns

### Form Labels
```properties
# English
labels.user_name = User Name
labels.email_address = Email Address
labels.password = Password

# Japanese
labels.user_name = ユーザー名
labels.email_address = メールアドレス
labels.password = パスワード
```

### Validation Errors
```properties
# English
errors.required = {0} is required.
errors.max_length = {0} must not exceed {1} characters.
errors.invalid_email = Please enter a valid email address.

# Japanese
errors.required = {0}は必須です。
errors.max_length = {0}は{1}文字以内で入力してください。
errors.invalid_email = 有効なメールアドレスを入力してください。
```

### Admin Messages
```properties
# English
success.crud_create = Created successfully.
success.crud_update = Updated successfully.
success.crud_delete = Deleted successfully.
confirm.delete_item = Are you sure you want to delete this item?

# Japanese
success.crud_create = 作成しました。
success.crud_update = 更新しました。
success.crud_delete = 削除しました。
confirm.delete_item = このアイテムを削除してもよろしいですか？
```

## Output

When adding new messages, provide:
1. The complete property entries for all supported languages
2. Example usage in Java/JSP code
3. Verification that the key doesn't conflict with existing keys
4. Any related messages that should also be updated
