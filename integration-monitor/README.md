# Integration Monitor

Integration Monitor is an early-stage Microsoft Dynamics 365 Business Central extension for monitoring and processing integration traffic through explicit inbox and outbox queues. The current codebase contains active outbox and inbox processing flows, retention cleanup for completed outbox traffic, a default HTTP/HTTPS transport, basic authentication profile storage, and a postal-code validation demo. It is still not production-ready: retry semantics, concurrency control, diagnostics, cleanup scheduling, permissions, and automated tests need hardening.

## Main Assumptions

- Outbound integration messages are stored in an outbox table before they are sent to external systems.
- Incoming responses can be stored in an inbox table for later processing when a message setup requires response handling.
- Message-specific behavior is selected through extensible enums and AL interfaces, so new message types can provide their own request builder and response processor.
- Transport-specific behavior is also selected through an interface and extensible enum, with HTTP/HTTPS implemented as the first default transport.
- Processing should be driven by job queue codeunits that pick eligible entries, apply retry rules, update statuses, and store payload or error details for review.
- Users should be able to inspect queue entries, retry or cancel failed work, and view or edit payloads through Business Central pages.
- Completed or cancelled outbox entries can be cleaned up per message type by configuring a retention DateFormula. Deleting an outbox entry also deletes its related inbox entries unless either side is currently being processed.

## Project Structure

```text
src/
  Auth/
    Authentication profile storage, Basic/Bearer secret handling, and auth pages.
  Helpers/
    Shared BLOB helper and generic BLOB viewer page.
  Inbox/
    Inbox entry storage, dispatcher, processor, failure handler, and monitoring page.
  Message/
    Message handler interface, message type enum, message setup checks, and default message behavior.
  Outbox/
    Outbox entry storage, dispatcher, processor, failure handler, cleanup job, entry management, and monitoring page.
  Setup/
    Message setup table, retention settings, validation, and administration page.
  Transport/
    Transport handler interface, transport enum, and default HTTP/HTTPS transport.
  demo/
    Postal-code validation demo message type, handler, job, and Post Code extensions.
Translations/
  Generated translation files.
```

## Objects

| Object | Type | Status | Purpose |
| --- | --- | --- | --- |
| `AMC Int. Outbox Status` | Enum 50102 | Active | Defines the outbox lifecycle values: ready to process, processing, processed, failed, and cancelled. `Processing` exists but is not claimed by the processors yet. |
| `AMC Int. Blob Helper` | Codeunit 50113 | Active | Provides helper procedures for reading text from BLOB fields and writing text into BLOB fields through `RecordRef`. It is used by the generic BLOB viewer and error display actions. |
| `AMC Int. Blob Viewer` | Page 50115 | Active | Generic card page for viewing or editing a selected BLOB field as text. It is reused by outbox and inbox payload actions. |
| `AMC Int. Message Type` | Enum 50103 | Active | Defines extensible integration message types and maps each enum value to an `AMC IMessageHandler` implementation. The current default value is `Default`; the demo extends it with `Postal Code Validation`. |
| `AMC IMessageHandler` | Interface | Active | Defines the contract for message-specific request building and response processing. Implementations decide how an outbox entry becomes an HTTP request and how an inbox response should be handled. |
| `AMC Message Handler Default` | Codeunit 50114 | Active | Default handler for generic messages. It builds a POST request from the outbox payload and configured endpoint, while response processing is currently an empty successful placeholder. |
| `AMC Message Mgt.` | Codeunit 50125 | Active | Provides shared message setup existence checks used by inbox and outbox entry validation. |
| `AMC Int. Transport Type` | Enum 50104 | Active | Defines extensible transport types and maps each value to an `AMC IHttpTransportHandler` implementation. The current default transport is HTTP/HTTPS. |
| `AMC IHttpTransportHandler` | Interface | Active | Defines the transport contract for sending a prepared request using message setup data. This keeps transport concerns separate from message-specific request construction. |
| `AMC Http Transport Default` | Codeunit 50117 | Active | Sends HTTP/HTTPS requests through `HttpClient`, applies timeout settings, applies configured authentication, and exposes before/after send integration events. It still ignores the Boolean return value from `HttpClient.Send`. |
| `AMC Int. Auth Type` | Enum 50105 | Active | Defines supported authentication modes: Basic and Bearer Token. |
| `AMC Int. Auth Profile` | Table 50109 | Active | Stores authentication profile metadata and tracks whether a secret is stored in isolated storage. |
| `AMC Int. Auth Profiles` | Page 50118 | Active | List page for authentication profiles. |
| `AMC Int. Auth Profile Card` | Page 50119 | Active | Card page for maintaining authentication profiles and setting or clearing stored secrets. |
| `AMC Int. Auth Profile Mgt.` | Codeunit 50120 | Active | Manages authentication profile secrets in isolated storage and validates profile readiness. |
| `AMC Int. Auth Applier` | Codeunit 50121 | Active | Applies Basic or Bearer authorization headers to outgoing HTTP requests. |
| `AMC Int. Message Setup` | Table 50108 | Active | Stores configuration per message type, including enablement, retry settings, endpoint URL, timeout, authentication profile code, response processing flag, transport type, and the outbox retention DateFormula. |
| `AMC Int. Message Setup Mgt.` | Codeunit 50122 | Active | Validates transport and authentication setup before a setup record can be enabled, and validates that configured outbox retention formulas resolve to a date before today. |
| `AMC Int. Message Setup List` | Page 50116 | Active | Read-only administration list page for browsing integration message setup records. It opens `AMC Int. Message Setup Card` for record editing. |
| `AMC Int. Message Setup Card` | Page 50117 | Active | Editable card page for maintaining one integration message setup record. It exposes the key processing, endpoint, retry, authentication, transport, and outbox retention settings. |
| `AMC Int. Outbox Entry` | Table 50107 | Active | Stores outbound integration messages, processing status, timestamps, retry count, request payload, error message, and source record reference. Insert triggers initialize creation and next attempt timestamps. Delete triggers validate processing state and delete related inbox entries. |
| `AMC Int. Outbox Entries` | Page 50113 | Active | List page for monitoring outbox entries. It provides actions to process, reset, cancel, view payload, edit payload, view error details, and open related inbox entries. |
| `AMC Outbox Dispatcher Job` | Codeunit 50115 | Active | Job entry point for finding outbox entries that are ready or failed and due for processing. It runs the outbox processor and delegates failures to the failure handler. |
| `AMC Outbox Processor` | Codeunit 50116 | Active | Processes a single outbox entry by loading setup, validating eligibility, building the request, sending it through the selected transport, validating the response, optionally creating an inbox entry, and marking the outbox entry as processed. |
| `AMC Outbox Failure Handler` | Codeunit 50118 | Active | Marks failed outbox processing attempts, increments attempt count, stores last error text, schedules the next attempt, or marks the entry as cancelled after max attempts. |
| `AMC Outbox Entry Mgt.` | Codeunit 50119 | Active | Centralizes outbox insert defaults, delete validation, related inbox cleanup, and page actions such as reset, cancel, process, payload view/edit, and error details. |
| `AMC Outbox Cleanup Job` | Codeunit 50131 | Active | Deletes processed or cancelled outbox entries older than the retention threshold configured on each message setup. Blank retention formulas disable cleanup for that message type. |
| `AMC Outbox Cleanup Processor` | Codeunit 50132 | Active | Table-bound processor that deletes one outbox entry with triggers enabled, allowing related inbox cleanup and processing guards to run. |
| `AMC Int. Inbox Entry` | Table 50106 | Active | Stores inbound response entries linked to outbox entries, including status, timestamps, retry count, response payload, error details, source record reference, and related outbox entry number. Insert triggers initialize creation and next attempt timestamps. Delete triggers block direct deletion while the related outbox entry still exists. |
| `AMC Int. Inbox Status` | Enum 50106 | Active | Defines the inbox lifecycle values: ready to process, processing, processed, failed, and cancelled. `Processing` exists but is not claimed by the processors yet. |
| `AMC Int. Inbox Entries` | Page 50114 | Active | List page for monitoring inbox entries. It provides actions to process, reset, cancel, view payload, edit payload, view error details, and open the related outbox entry. |
| `AMC Inbox Entry Mgt.` | Codeunit 50126 | Active | Centralizes inbox insert defaults, delete guards, and page actions such as reset, cancel, process, payload view/edit, and error details. |
| `AMC Inbox Processor` | Codeunit 50127 | Active | Processes a single inbox entry by loading setup, validating eligibility, and calling the message handler response processor before marking the entry as processed. |
| `AMC Inbox Failure Handler` | Codeunit 50128 | Active | Marks failed inbox processing attempts, increments attempt count, stores last error text, schedules the next attempt, or marks the entry as cancelled after max attempts. |
| `AMC Inbox Dispatcher Job` | Codeunit 50130 | Active | Job entry point for finding inbox entries that are ready or failed and due for processing. |
| `AMC Demo Message Type` | EnumExtension 50123 | Active demo | Adds the postal-code validation message type. |
| `AMC Post Code Demo` | TableExtension 50123 | Active demo | Extends `Post Code` with validation state fields and reset behavior. |
| `AMC Post Codes Demo` | PageExtension 50123 | Active demo | Adds postal-code validation and reset actions to `Post Codes`. The reset action clears validation state and reports that related queue entries were removed when present. |
| `AMC Post Code Validation Mgt` | Codeunit 50123 | Active demo | Creates postal-code validation outbox entries and deletes unprocessed validation outbox entries when source data changes, relying on outbox delete triggers to remove related inbox entries. |
| `AMC Post Code Valid Msg Hdlr` | Codeunit 50124 | Active demo | Builds the OpenDataSoft postal-code validation request and processes inbox responses back into the source `Post Code`. |
| `AMC Validation Status` | Enum 50125 | Active demo | Defines postal-code validation states. |
| `AMC Post Code Validation Job` | Codeunit 50129 | Active demo | Creates validation requests for post codes that have not been validated yet. |

## Demo: Postal Code Validation

The project includes a small demo that shows how a Business Central action can create outbox entries and send a real HTTP request through the integration framework.

The demo extends the standard `Post Code` table with `Validation Status`, `Validated At`, and `Validated By`. Changing `Code`, `City`, `Country/Region Code`, or `County` clears the validation fields and deletes unprocessed validation outbox entries. Related inbox entries are removed through the outbox delete trigger. The `Post Codes` page has a `Validate` action that creates `AMC Int. Outbox Entry` records for the selected post code rows.

The demo message type is `Postal Code Validation`. Its handler reads the outbox payload and sends this request:

```text
GET {Endpoint URL}?where=country_code="{countryRegionCode}" AND postal_code="{code}"&limit=10
```

For example, with `Endpoint URL` set to `https://public.opendatasoft.com/api/explore/v2.1/catalog/datasets/geonames-postal-code/records`, a US postal code request can become:

```text
GET https://public.opendatasoft.com/api/explore/v2.1/catalog/datasets/geonames-postal-code/records?where=country_code%3D%22US%22%20AND%20postal_code%3D%2290210%22&limit=10
```

If `Process Response` is enabled in the message setup, the HTTP response is stored in the inbox. Processing that inbox response validates the source `Post Code` record. `Validation Status` becomes `Invalid` when OpenDataSoft returns an empty `results` array. It becomes `Valid` only when one result has `country_code` matching `Country/Region Code`, `postal_code` matching `Code`, `admin_code1` matching `County`, and `City` matching either `place_name` or `admin_name1`.

Example response:

```json
{
  "total_count": 1,
  "results": [
    {
      "country_code": "US",
      "postal_code": "90210",
      "place_name": "Beverly Hills",
      "admin_name1": "California",
      "admin_code1": "CA",
      "latitude": 34.0901,
      "longitude": -118.4065
    }
  ]
}
```

### Demo Configuration

Create an `AMC Int. Message Setup` record for message type `Postal Code Validation` with these values:

| Field | Value |
| --- | --- |
| `Endpoint URL` | `https://public.opendatasoft.com/api/explore/v2.1/catalog/datasets/geonames-postal-code/records` |
| `Transport` | `HTTP/HTTPS` |
| `Enabled` | `true` |
| `Process Response` | `true` |
| `Auth Profile Code` | blank |
| `Max Attempts` | `1` |
| `Base Retry Delay (sec)` | `60` |
| `Timeout (ms)` | `10000` |
| `Delete Outbox Entr. Older Than` | optional, for example `<-30D>` |

The Business Central environment must allow outbound HTTPS requests to `https://public.opendatasoft.com`.

### Demo Usage

1. Open `Zip Codes`.
2. Select one or more rows with `Code`, `City`, `Country/Region Code`, and `County`.
3. Run `Validate`.
4. Inspect the created entries in `AMC Int. Outbox Entries`.
5. Run or schedule `AMC Outbox Dispatcher Job`.
6. Inspect the inbox payload if response processing is enabled.

## TODO

### Current Status

- Outbox and inbox are active flows, not commented drafts. Both have entry tables, status enums, dispatcher jobs, processors, failure handlers, list pages, and payload/error actions through the generic BLOB viewer.
- Authentication profiles, isolated-storage secrets, Basic auth, and Bearer token auth are implemented and connected to the default HTTP transport.
- Processed and cancelled outbox entries can be cleaned up by `AMC Outbox Cleanup Job` based on the per-message retention formula. Related inbox entries are deleted through outbox delete triggers.
- The postal-code validation demo can enqueue outbox entries and process responses through the inbox flow.

### Problems To Fix

- Successful processing does not update `Attempt Count` or `Last Attempt At`; failure handlers also write failure time into `Processed At`, which makes the field semantics unclear.
- Max attempts still changes status to `Cancelled` in both failure handlers. This mixes an automatic terminal failure with a manual cancellation and makes reset/retry rules ambiguous.
- `Processing` exists in both status enums, but neither dispatcher claims entries before processing. Two job queue sessions can still pick the same due entry.
- The outbox flow still has no generic enqueue API. The demo inserts outbox records directly and writes the BLOB itself, so future callers would need to know the internal insert and payload rules.
- `HttpClient.Send` result is ignored. Runtime send failures should become explicit processing errors with useful diagnostics.
- HTTP diagnostics are still minimal. Entries do not store endpoint, method, status code, response summary, duration, or correlation/idempotency data.
- If the HTTP call succeeds but inbox entry creation fails, the dispatcher can retry the outbound call and create a duplicate external side effect.
- Setup validation is now present when enabling a setup record, but runtime processor validation is still effectively a no-op and can be bypassed by direct data changes or code. Response-processing requirements also need clearer validation.
- Reset actions clear error details, reset attempt count, and make entries ready again, but the guard against resetting `Processed` or `Processing` entries is commented out. Decide whether reset is a fresh retry, an operator override, or both.
- Review the code for top-down readability and performance, especially the duplicated outbox/inbox processor and failure-handler patterns.
- Rename the app
- Add job queue setup guidance or assisted setup for the outbox, inbox, and cleanup dispatchers.
- Add permissions, role center/search discoverability, and any required page actions for normal users.
- Automated tests are still missing for outbox eligibility, request building, successful dispatch, HTTP failure, retry scheduling, max attempts, manual reset/cancel, response-to-inbox creation, inbox response processing, and auth validation.
