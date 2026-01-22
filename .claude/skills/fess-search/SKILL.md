---
name: fess-search
description: Build and optimize OpenSearch search queries for Fess. Use when working with search functionality, filters, or relevance tuning.
---

# Fess Search Query Builder

This skill helps you design, build, and optimize search queries for Fess using OpenSearch.

## When to Use

- Building new search features
- Optimizing search relevance
- Implementing filters and facets
- Debugging search issues
- Performance tuning search queries

## Workflow

### 1. Understand the Requirement

First, clarify the search requirements:
- What fields should be searched?
- What filters are needed?
- What sorting is required?
- Are facets/aggregations needed?
- What is the expected result format?

### 2. Analyze Existing Implementation

Look at the existing search implementation in Fess:

```
repos/fess/src/main/java/org/codelibs/fess/
├── es/query/          # Query builder classes
├── helper/SearchHelper.java  # Search coordination
└── entity/SearchRequestParams.java  # Search parameters
```

### 3. Build the Query

#### Basic Match Query
```java
QueryBuilder query = QueryBuilders.matchQuery("content", keyword);
```

#### Multi-field Search with Boosting
```java
QueryBuilder query = QueryBuilders.multiMatchQuery(keyword)
    .field("title", 3.0f)      // Title gets 3x boost
    .field("content", 1.0f)
    .field("url", 0.5f)
    .type(MultiMatchQueryBuilder.Type.BEST_FIELDS);
```

#### Boolean Query with Filters
```java
BoolQueryBuilder boolQuery = QueryBuilders.boolQuery()
    .must(QueryBuilders.matchQuery("content", keyword))
    .filter(QueryBuilders.termQuery("filetype", "pdf"))
    .filter(QueryBuilders.rangeQuery("lastModified").gte("now-1M"))
    .mustNot(QueryBuilders.termQuery("status", "archived"));
```

#### Phrase Search
```java
QueryBuilder phraseQuery = QueryBuilders.matchPhraseQuery("content", phrase)
    .slop(2);  // Allow 2 words between terms
```

#### Fuzzy Search (Typo Tolerance)
```java
QueryBuilder fuzzyQuery = QueryBuilders.matchQuery("content", keyword)
    .fuzziness(Fuzziness.AUTO);
```

### 4. Add Facets (Aggregations)

```java
SearchSourceBuilder builder = new SearchSourceBuilder()
    .query(mainQuery)
    .aggregation(AggregationBuilders.terms("by_filetype")
        .field("filetype.keyword")
        .size(10))
    .aggregation(AggregationBuilders.terms("by_site")
        .field("site.keyword")
        .size(10))
    .aggregation(AggregationBuilders.dateHistogram("by_date")
        .field("lastModified")
        .calendarInterval(DateHistogramInterval.MONTH));
```

### 5. Add Highlighting

```java
builder.highlighter(new HighlightBuilder()
    .field("title")
    .field("content")
    .preTags("<strong>")
    .postTags("</strong>")
    .fragmentSize(150)
    .numOfFragments(3));
```

### 6. Implement Sorting

```java
builder.sort("_score", SortOrder.DESC)  // Primary: relevance
    .sort("lastModified", SortOrder.DESC);  // Secondary: date
```

### 7. Handle Pagination

```java
builder.from(page * pageSize)
    .size(pageSize);
```

## Best Practices

### Relevance Tuning
- Boost important fields (title > content)
- Use `function_score` for custom ranking
- Consider freshness boosting for time-sensitive content

### Performance
- Use `filter` context for non-scoring criteria (cached)
- Limit returned `_source` fields
- Set reasonable `size` limits
- Use `terminate_after` for counting

### Error Handling
- Handle empty queries gracefully
- Escape special characters in user input
- Set appropriate timeouts
- Handle search exceptions

## Testing Queries

Test queries directly against OpenSearch:

```bash
# Test query
curl -X POST "localhost:9200/fess/_search?pretty" \
  -H 'Content-Type: application/json' \
  -d '{
    "query": {
      "match": {
        "content": "test keyword"
      }
    }
  }'

# Explain scoring
curl -X POST "localhost:9200/fess/_explain/doc_id?pretty" \
  -H 'Content-Type: application/json' \
  -d '{
    "query": {
      "match": {
        "content": "test"
      }
    }
  }'
```

## Output

After building the query, provide:
1. The complete Java query builder code
2. Explanation of how it works
3. Sample curl command for testing
4. Performance considerations
5. Alternative approaches if relevant
