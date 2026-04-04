# Checklist: API Endpoints and SSE Events

Detailed verification rules for REST API endpoints and Server-Sent Events.

## C. API Endpoints and HTTP Methods

- Verify paths (e.g., `/api/v1/chat`) against path constants or `@Execute` annotations.
- Check supported HTTP methods by reading the method validation logic (e.g., `if (!"POST".equalsIgnoreCase(request.getMethod()))` patterns in the handler class). Some endpoints accept multiple methods (e.g., GET and POST) even if docs show only one.
- Verify request/response parameter names and types.
- **Undocumented request parameters**: Read all `request.getParameter()` calls and parameter-parsing helper methods (e.g., `parseFieldFilters()`, `parseExtraQueries()`) in the API handler class. Parameters accepted by the code but missing from the doc's parameter table should be reported as MISSING. Common undocumented parameters include filter/facet parameters (`fields.label`, `ex_q`) that are passed through to search logic.
- **Parameter name mismatch between docs and code**: Docs may use intuitive/standard parameter names (e.g., `size`, `scroll`) that differ from actual parameter names in code (e.g., `num`). Always check the inner `RequestParams` class (e.g., `JsonRequestParams`) of the API handler for the exact `request.getParameter("xxx")` calls. A documented parameter that has no corresponding `getParameter()` call does not exist as a user-facing parameter — it may be a server-side config or entirely fabricated by the doc author.
- **RBAC/authentication propagation**: When docs describe authentication or role-based access for an endpoint, verify whether the handler actually passes user context to the processing layer. Check the `userBean` argument passed to the service method (e.g., `searchHelper.scrollSearch(..., userBean)`). If `OptionalThing.empty()` is passed instead of actual user information, RBAC is NOT applied and all matching results are returned regardless of permissions. Docs implying role-based filtering works when it doesn't should be reported as INCORRECT.

## D. SSE Event Types

- For streaming APIs, verify event names against `sendSseEvent(writer, "eventName", ...)` calls.
- Check event payload fields match documentation.
- Confirm no documented events are missing from source, and no source events are missing from docs.
