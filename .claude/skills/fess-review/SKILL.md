---
name: fess-review
description: Use when reviewing Fess code or pull requests for LastaFlute patterns, security, or performance.
context: fork
---

# Fess Code Review

This skill performs comprehensive code review for Fess, focusing on framework patterns, security, performance, and best practices.

## When to Use

- Reviewing pull requests
- Checking code before commit
- Validating implementation approach
- Identifying potential issues
- Ensuring code quality

## Review Checklist

### 1. LastaFlute Patterns

#### Action Classes
- [ ] `@Execute` annotation present and correctly configured
- [ ] Appropriate response type (HtmlResponse, JsonResponse, etc.)
- [ ] Form validation using `validate()` or `validateApi()`
- [ ] Proper error handling
- [ ] No business logic in Actions (delegate to Service/Logic)

```java
// Good
@Execute
public JsonResponse<Result> getData(MyForm form) {
    validateApi(form, messages -> {});
    Result result = myService.process(form);
    return asJson(result);
}

// Bad - business logic in action
@Execute
public JsonResponse<Result> getData(MyForm form) {
    // Business logic should be in service
    List<Item> items = itemBhv.selectList(cb -> {
        cb.query().setStatus_Equal("active");
    });
    // ...
}
```

#### Form Classes
- [ ] Appropriate validation annotations
- [ ] Proper field types
- [ ] Serializable implemented
- [ ] No business logic in Forms

### 2. DBFlute Usage

#### ConditionBean
- [ ] Type-safe queries used (no raw SQL unless necessary)
- [ ] Proper use of `setupSelect` for eager loading
- [ ] Paging used for large result sets
- [ ] Index-friendly queries

```java
// Good - eager loading
UserCB cb = new UserCB();
cb.setupSelect_Group();  // Avoid N+1
cb.query().setStatus_Equal("active");
cb.paging(20, 1);

// Bad - N+1 problem
List<User> users = userBhv.selectList(cb);
users.forEach(u -> {
    Group g = u.getGroup();  // N+1 query!
});
```

#### N+1 Detection
- [ ] No getRelated() calls inside loops without setupSelect
- [ ] Batch operations for bulk updates/deletes

### 3. OpenSearch Queries

#### Query Building
- [ ] Use filter context for non-scoring criteria
- [ ] Appropriate field boosting
- [ ] Pagination limits enforced
- [ ] Query complexity reasonable

```java
// Good - filter for exact match, scoring for text search
BoolQueryBuilder query = QueryBuilders.boolQuery()
    .must(QueryBuilders.matchQuery("content", keyword))
    .filter(QueryBuilders.termQuery("status", "active"));

// Bad - using must for exact match wastes scoring
BoolQueryBuilder query = QueryBuilders.boolQuery()
    .must(QueryBuilders.termQuery("status", "active"));
```

### 4. Security

#### Input Validation
- [ ] All user input validated
- [ ] Appropriate size limits
- [ ] Special characters handled

#### XSS Prevention
- [ ] Output encoding in JSP
- [ ] No raw HTML output from user data

```jsp
<!-- Good - encoded output -->
<c:out value="${userInput}"/>

<!-- Bad - XSS vulnerability -->
${userInput}
```

#### SQL/NoSQL Injection
- [ ] No string concatenation in queries
- [ ] Parameterized queries used

```java
// Good - parameterized
cb.query().setName_Equal(userInput);

// Bad - injection risk
String sql = "SELECT * FROM user WHERE name = '" + userInput + "'";
```

#### Authentication/Authorization
- [ ] Proper permission checks
- [ ] Session management correct
- [ ] Sensitive data protected

### 5. Performance

#### Database
- [ ] Index-friendly queries
- [ ] Avoid SELECT *
- [ ] Use batch operations for bulk
- [ ] Connection handling correct

#### Search
- [ ] Result size limited
- [ ] Timeout configured
- [ ] Heavy aggregations avoided
- [ ] Source filtering used

#### Memory
- [ ] No unbounded collections
- [ ] Streams used for large data
- [ ] Resources properly closed

```java
// Good - try-with-resources
try (InputStream is = file.getInputStream()) {
    // process
}

// Bad - resource leak
InputStream is = file.getInputStream();
// process - no close
```

### 6. Internationalization

- [ ] User-facing strings in message properties
- [ ] Proper message keys
- [ ] All supported languages have translations

```java
// Good
messageManager.getMessage("labels.success_saved");

// Bad - hardcoded string
return "Saved successfully";
```

### 7. Error Handling

- [ ] Appropriate exception types
- [ ] Meaningful error messages
- [ ] Proper logging
- [ ] User-friendly error display

```java
// Good
try {
    service.process(data);
} catch (ValidationException e) {
    logger.debug("Validation failed: {}", e.getMessage());
    throw new ClientErrorException(e.getMessage());
} catch (Exception e) {
    logger.error("Processing failed", e);
    throw new SystemException("An error occurred", e);
}
```

### 8. Code Quality

#### Naming
- [ ] Clear, descriptive names
- [ ] Follows Fess conventions
- [ ] No abbreviations (except common ones)

#### Structure
- [ ] Single responsibility
- [ ] Methods not too long (< 30 lines ideal)
- [ ] Appropriate abstraction level

#### Documentation
- [ ] Complex logic commented
- [ ] Public APIs documented
- [ ] No commented-out code

## Review Output Format

```markdown
## Code Review Summary

### Critical Issues
- [SECURITY] Issue description (file:line)
- [PERFORMANCE] Issue description (file:line)

### Improvements Recommended
- [PATTERN] Suggestion (file:line)
- [QUALITY] Suggestion (file:line)

### Minor Suggestions
- Style/formatting issues

### Positive Observations
- Well-implemented aspects
```

## Severity Levels

| Level | Description | Action Required |
|-------|-------------|-----------------|
| 🔴 Critical | Security/data issues | Must fix before merge |
| 🟠 Major | Significant problems | Should fix before merge |
| 🟡 Minor | Code quality issues | Fix if time permits |
| 🟢 Suggestion | Best practice tips | Optional improvement |

## Output

After review, provide:
1. Summary of findings by severity
2. Specific issues with file/line references
3. Code examples for recommended fixes
4. Overall assessment and recommendation
