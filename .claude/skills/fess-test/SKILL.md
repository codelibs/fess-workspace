---
name: fess-test
description: Use when writing unit or integration tests for Fess components.
context: fork
---

# Fess Test Generator

This skill helps you create comprehensive tests for Fess components, following JUnit 5 and Fess testing patterns.

## When to Use

- Writing unit tests for new features
- Creating integration tests
- Adding test coverage for existing code
- Setting up test data and mocks
- Verifying bug fixes

## Test Structure in Fess

```
repos/fess/src/test/java/org/codelibs/fess/
├── helper/          # Helper class tests
├── util/            # Utility class tests
├── app/             # Action/Service tests
│   ├── web/         # Web layer tests
│   └── service/     # Service layer tests
├── es/              # OpenSearch integration tests
└── it/              # Integration test suites
```

## Workflow

### 1. Analyze the Target Code

Before writing tests:
1. Identify the class/method to test
2. Understand its dependencies
3. Determine edge cases
4. Check existing test patterns

### 2. Unit Test Template

```java
package org.codelibs.fess.helper;

import org.codelibs.fess.unit.UnitFessTestCase;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;

public class MyHelperTest extends UnitFessTestCase {

    private MyHelper myHelper;

    @BeforeEach
    public void setUp() {
        myHelper = new MyHelper();
    }

    @Test
    public void testBasicFunctionality() {
        // Given
        String input = "test";

        // When
        String result = myHelper.process(input);

        // Then
        assertEquals("expected", result);
    }

    @Test
    public void testNullInput() {
        assertThrows(NullPointerException.class, () -> {
            myHelper.process(null);
        });
    }

    @Test
    public void testEmptyInput() {
        // Given
        String input = "";

        // When
        String result = myHelper.process(input);

        // Then
        assertEquals("", result);
    }
}
```

### 3. Testing with Mocks (Mockito)

```java
import org.mockito.Mock;
import org.mockito.MockitoAnnotations;
import static org.mockito.Mockito.*;

public class MyServiceTest extends UnitFessTestCase {

    @Mock
    private FessConfig fessConfig;

    @Mock
    private SearchEngineClient searchEngineClient;

    private MyService myService;

    @BeforeEach
    public void setUp() {
        MockitoAnnotations.openMocks(this);
        myService = new MyService();
        myService.fessConfig = fessConfig;
        myService.searchEngineClient = searchEngineClient;
    }

    @Test
    public void testSearchWithConfig() {
        // Given
        when(fessConfig.getSearchResultSize()).thenReturn(20);
        when(searchEngineClient.search(any())).thenReturn(mockResults());

        // When
        SearchResult result = myService.search("keyword");

        // Then
        assertNotNull(result);
        verify(searchEngineClient).search(any());
    }
}
```

### 4. Testing Actions (Web Layer)

```java
public class SearchActionTest extends UnitFessTestCase {

    private SearchAction searchAction;

    @Mock
    private SearchHelper searchHelper;

    @BeforeEach
    public void setUp() {
        MockitoAnnotations.openMocks(this);
        searchAction = new SearchAction();
        searchAction.searchHelper = searchHelper;
    }

    @Test
    public void testSearchWithValidQuery() {
        // Given
        SearchForm form = new SearchForm();
        form.q = "test query";

        when(searchHelper.search(any())).thenReturn(mockSearchResult());

        // When
        JsonResponse<SearchResult> response = searchAction.search(form);

        // Then
        assertNotNull(response);
    }

    @Test
    public void testSearchWithEmptyQuery() {
        // Given
        SearchForm form = new SearchForm();
        form.q = "";

        // When & Then
        assertThrows(ValidationException.class, () -> {
            searchAction.search(form);
        });
    }
}
```

### 5. Integration Tests

```java
public class SearchIntegrationTest extends IntegrationFessTestCase {

    @Test
    public void testEndToEndSearch() {
        // Index test document
        indexDocument("test_id", "Test Title", "Test content for search");

        // Wait for indexing
        refreshIndex();

        // Perform search
        SearchResult result = searchService.search("test");

        // Verify
        assertTrue(result.getDocumentCount() > 0);
        assertTrue(result.getDocuments().stream()
            .anyMatch(d -> d.getTitle().contains("Test")));
    }
}
```

### 6. Test Data Builders

```java
public class TestDataBuilder {

    public static User createTestUser() {
        User user = new User();
        user.setId(1L);
        user.setName("testuser");
        user.setEmail("test@example.com");
        return user;
    }

    public static SearchResult createSearchResult(int docCount) {
        List<Document> docs = IntStream.range(0, docCount)
            .mapToObj(i -> createDocument(i))
            .collect(Collectors.toList());
        return new SearchResult(docs, docCount);
    }

    private static Document createDocument(int index) {
        Document doc = new Document();
        doc.setId("doc_" + index);
        doc.setTitle("Document " + index);
        return doc;
    }
}
```

## Test Categories

### Unit Tests
- Test single classes in isolation
- Mock all dependencies
- Fast execution
- High coverage target

### Integration Tests
- Test component interactions
- Use real dependencies where feasible
- Test database/search operations
- Slower but more realistic

### End-to-End Tests
- Test full workflows
- Use real Fess instance
- Verify user scenarios
- Run in CI/CD pipeline

## Best Practices

### Test Naming
```java
@Test
public void testMethodName_scenario_expectedBehavior() { }

// Examples:
public void testSearch_withValidKeyword_returnsResults() { }
public void testSearch_withEmptyQuery_throwsException() { }
public void testDelete_nonExistentId_returnsNotFound() { }
```

### Test Structure (AAA Pattern)
```java
@Test
public void testExample() {
    // Arrange (Given)
    // Set up test data and mocks

    // Act (When)
    // Call the method under test

    // Assert (Then)
    // Verify the results
}
```

### Coverage Goals
- Line coverage: > 80%
- Branch coverage: > 70%
- Critical paths: 100%

## Common Assertions

```java
// Null checks
assertNotNull(result);
assertNull(result.getError());

// Equality
assertEquals(expected, actual);
assertNotEquals(forbidden, actual);

// Boolean
assertTrue(result.isSuccess());
assertFalse(result.isEmpty());

// Collections
assertIterableEquals(expectedList, actualList);
assertTrue(list.contains(item));
assertEquals(3, list.size());

// Exceptions
assertThrows(IllegalArgumentException.class, () -> method());
assertDoesNotThrow(() -> method());
```

## Output

When generating tests, provide:
1. Complete test class with imports
2. Test cases for happy path
3. Test cases for edge cases and errors
4. Mock setup if dependencies exist
5. Comments explaining test rationale
