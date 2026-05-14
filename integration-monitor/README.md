# Integration Monitor

Integration Monitor is an early-stage Microsoft Dynamics 365 Business Central extension for monitoring and processing integration traffic through explicit inbox and outbox queues. The current codebase mainly defines the intended architecture and core object model; the application is not production-ready yet and several parts are placeholders or commented-out drafts.

## Main Assumptions

- Outbound integration messages are stored in an outbox table before they are sent to external systems.
- Incoming responses can be stored in an inbox table for later processing when a message setup requires response handling.
- Message-specific behavior is selected through extensible enums and AL interfaces, so new message types can provide their own request builder and response processor.
- Transport-specific behavior is also selected through an interface and extensible enum, with HTTP implemented as the first default transport.
- Processing should be driven by job queue codeunits that pick eligible entries, apply retry rules, update statuses, and store payload or error details for review.
- Users should be able to inspect queue entries, retry or cancel failed work, and view or edit payloads through Business Central pages.

## Project Structure

```text
src/
  Common/
    Shared queue status definitions.
  Helpers/
    Shared helper codeunits used by multiple features.
  Inbox/
    Inbox entry storage and draft inbox processing UI/job objects.
  MessageType/
    Message handler interface, message type enum, and default message behavior.
  Outbox/
    Outbox entry storage, dispatcher and processor logic, and monitoring pages.
  Setup/
    Message setup table and administration page.
  TransportType/
    Transport handler interface, transport enum, and default HTTP transport.
Translations/
  Generated translation files.
```

## Objects

| Object | Type | Status | Purpose |
| --- | --- | --- | --- |
| `AMC Int. Queue Status` | Enum 50102 | Active | Defines the shared queue lifecycle values: ready to process, sent, failed, and cancelled. It is currently used by both inbox and outbox entries. |
| `AMC Int. Blob Helper` | Codeunit 50109 | Active | Provides helper procedures for reading text from BLOB fields and writing text into BLOB fields through `RecordRef`. It is used by payload and error pages, and by outbox error handling. |
| `AMC Int. Message Type` | Enum 50103 | Active | Defines extensible integration message types and maps each enum value to an `AMC IMessageHandler` implementation. The current default value is `Generic`. |
| `AMC IMessageHandler` | Interface | Active | Defines the contract for message-specific request building and response processing. Implementations decide how an outbox entry becomes an HTTP request and how an inbox response should be handled. |
| `AMC Message Handler Default` | Codeunit 50110 | Active | Default handler for generic messages. It builds a POST request from the outbox payload and configured endpoint, while response processing is currently only a successful placeholder. |
| `AMC Int. Transport Type` | Enum 50104 | Active | Defines extensible transport types and maps each value to an `AMC IHttpTransportHandler` implementation. The current default transport is HTTP. |
| `AMC IHttpTransportHandler` | Interface | Active | Defines the transport contract for sending a prepared request using message setup data. This keeps transport concerns separate from message-specific request construction. |
| `AMC Http Transport Default` | Codeunit 50113 | Active | Sends HTTP requests through `HttpClient`, applies timeout settings, and exposes an integration event for authentication. Authentication storage and concrete authentication handling are not implemented yet. |
| `AMC Int. Message Setup` | Table 50108 | Active | Stores configuration per message type, including enablement, retry settings, endpoint URL, timeout, authentication profile code, response processing flag, and transport type. |
| `AMC Int. Message Setup` | Page 50116 | Active | Read-only administration list page for browsing integration message setup records. It opens `AMC Int. Message Setup Card` for record editing. |
| `AMC Int. Message Setup Card` | Page 50117 | Active | Editable card page for maintaining one integration message setup record. It exposes the key processing, endpoint, retry, authentication, and transport settings. |
| `AMC Int. Outbox Entry` | Table 50107 | Active | Stores outbound integration messages, processing status, timestamps, retry count, request payload, error message, and source record reference. Insert triggers initialize creation and next attempt timestamps. |
| `AMC Int. Outbox Entries` | Page 50113 | Active | List page for monitoring outbox entries. It provides actions to retry, cancel, view payload, edit payload, and view error details. |
| `AMC Int. Outbox Payload` | Page 50115 | Active | Card page for viewing or editing the request payload stored on an outbox entry. It uses `AMC Int. Blob Helper` to move data between text and the BLOB field. |
| `AMC Int. Outbox Error` | Page 50114 | Active | Read-only card page for viewing the error message BLOB stored on an outbox entry. It is intended for troubleshooting failed dispatch attempts. |
| `AMC Outbox Dispatcher Job` | Codeunit 50111 | Active | Job entry point for finding outbox entries that are ready or failed and due for processing. It runs the outbox processor and marks entries as failed or cancelled when processing errors occur. |
| `AMC Outbox Processor` | Codeunit 50112 | Active | Processes a single outbox entry by loading setup, validating eligibility, building the request, sending it through the selected transport, validating the response, and optionally creating an inbox entry. Several error handling and retry details are still marked as TODO in the code. |
| `AMC Int. Inbox Entry` | Table 50106 | Active | Stores inbound response entries linked to outbox entries, including status, correlation ID, timestamps, retry count, response payload, and error details. Insert triggers initialize timestamps and correlation ID. |
| `AMC Inbox Processor Job` | Codeunit 50109 | Commented out draft | Draft job for processing inbox entries through the message handler response processor. It is currently disabled and also conflicts with the active `AMC Int. Blob Helper` object ID. |
| `AMC Int. Inbox Entries` | Page 50113 | Commented out draft | Draft list page for monitoring inbox entries and accessing response and error pages. It is currently disabled and conflicts with the active outbox entries page ID. |
| `AMC Int. Inbox Payload` | Page 50116 | Commented out draft | Draft card page for viewing or editing response payload BLOB data. It is currently disabled and conflicts with the active message setup page ID. |
| `AMC Int. Inbox Error` | Page 50118 | Commented out draft | Draft read-only card page for displaying inbox error details. It is currently disabled and depends on the disabled inbox page flow. |

## Demo: Postal Code City Validation

The project includes a small demo that shows how a Business Central action can create outbox entries and send a real HTTP request through the integration framework.

The demo extends the standard `Post Code` table with `City Validation Status` and `City Validated At`. Changing `Code`, `City`, or `Country/Region Code` clears the validation status and timestamp. The `Post Codes` page has a `Validate City` action that creates `AMC Int. Outbox Entry` records for the selected post code rows.

The demo message type is `Postal Code Validation`. Its handler reads the outbox payload and sends this request:

```text
GET {Endpoint URL}/{countryRegionCode}/{code}
```

For example, with `Endpoint URL` set to `https://api.zippopotam.us`, a Polish post code request can become:

```text
GET https://api.zippopotam.us/PL/00-001
```

If `Process Response` is enabled in the message setup, the HTTP response is stored in the inbox. Processing that inbox response into `Valid` or `Invalid` is intentionally not implemented yet.

### Demo Configuration

Create an `AMC Int. Message Setup` record for message type `Postal Code Validation` with these values:

| Field | Value |
| --- | --- |
| `Endpoint URL` | `https://api.zippopotam.us` |
| `Transport` | `HTTP` |
| `Enabled` | `true` |
| `Process Response` | `true` |
| `Auth Profile Code` | blank |
| `Max Attempts` | `3` |
| `Base Retry Delay (sec)` | `60` |
| `Timeout (ms)` | `10000` |

The Business Central environment must allow outbound HTTP requests to `https://api.zippopotam.us`.

### Demo Usage

1. Open `Post Codes`.
2. Select one or more rows with `Country/Region Code` and `Code`.
3. Run `Validate City`.
4. Inspect the created entries in `AMC Int. Outbox Entries`.
5. Run or schedule `AMC Outbox Dispatcher Job`.
6. Inspect the inbox payload if response processing is enabled.

## TODO

### Make Outbox Work

DOKONCZYLEM LOGIKE W SETUPIE i OUTBOX DISPATCHER
Przejrzec auth tak zeby deklaracje funkcji byly w tabeli
WYSLAC
  OUTBOX PROCESSOR i MESSAGE HANDLER SPRAWDZONY TERAZ SPRAWDZIC TRANSPORT HANDLER
ZROBIC DEMO APP, KTORE COS WYSYLA Z UZYCIEM TEGO MECHANIZMU
  - tlumaczenie payment terms code
  - pobieranie dancych o firmie na podstawie nip

#### What Is Already Done

- `AMC Int. Outbox Entry` stores outbound queue entries with message type, status, timestamps, attempt count, request payload, error message, and source record reference.
- The outbox table has a `StatusNextAttempt` key, which matches the intended job queue lookup pattern for due entries.
- Insert logic initializes `Created At` and `Next Attempt At`, so newly inserted entries can become eligible immediately.
- `AMC Int. Outbox Entries` provides a monitoring page with retry, cancel, view payload, edit payload, and view error details actions.
- `AMC Int. Outbox Payload` and `AMC Int. Outbox Error` provide basic BLOB-to-text UI for request payloads and stored error details.
- `AMC Outbox Dispatcher Job` scans ready or failed entries where `Next Attempt At` is due and calls `AMC Outbox Processor` for each entry.
- `AMC Outbox Processor` contains the intended processing flow: load setup, check eligibility, validate setup, build request, send request, validate response, optionally create inbox entry, and mark the outbox entry as sent.
- `AMC IMessageHandler` and `AMC Int. Message Type` separate message-specific request and response behavior from the generic outbox processor.
- `AMC IHttpTransportHandler` and `AMC Int. Transport Type` separate transport behavior from message handling, with `AMC Http Transport Default` as the first HTTP implementation.

#### Current Flow

1. A record is inserted into `AMC Int. Outbox Entry`, normally with `Message Type`, `Status`, and `Request Payload`.
2. The table initializes `Created At` and `Next Attempt At` if they were not set by the caller.
3. `AMC Outbox Dispatcher Job` filters entries with status `ReadyToProcess` or `Failed` and `Next Attempt At <= CurrentDateTime()`.
4. For each due entry, the dispatcher calls `AMC Outbox Processor` through `Codeunit.Run`.
5. The processor loads `AMC Int. Message Setup` for the entry message type.
6. The processor checks whether the entry should be processed and validates that setup is enabled and has an endpoint URL.
7. The selected message handler builds an HTTP request from the outbox entry payload.
8. The selected transport handler sends the request.
9. The processor treats non-success HTTP status codes as errors.
10. If `Process Response` is enabled, the response body is written to a new inbox entry.
11. The outbox entry is marked as `Sent` and `Sent At` is set.
12. If the processor errors, the dispatcher tries to mark the outbox entry as failed, increments the attempt count, calculates the next attempt time, and stores the error text and call stack.

#### Problems To Fix

- `DoShouldProcessEntry` currently never returns `true`, so the processor exits without sending anything even when the dispatcher finds a due entry.
- The `Next Attempt At` check is reversed. Due entries with `Next Attempt At < CurrentDateTime()` are rejected, but future entries should be rejected instead.
- `OnBeforeShouldProcessEntry` is declared but never called, and the `IsHandled` pattern is incomplete.
- `IntMessageSetup.Get` is unprotected in the processor and default message handler. If setup is missing, processing fails before a controlled outbox failure can be recorded.
- In `AMC Int. Blob Helper`, `WriteTextToBlob` writes to `AnyRecord` but calls `Modify` on an uninitialized `RecRef`, so payload and error BLOB writes are not reliable.
- `MarkOutboxAsFailed` relies on the BLOB helper to persist the whole modified record. Because the helper is broken, status, attempt count, next attempt time, and error details may not be saved.
- If setup is missing, `MarkOutboxAsFailed` exits without changing the entry, which can leave the same entry ready for repeated failing attempts.
- `Attempt Count` and `Last Attempt At` are updated only on failure. A successful attempt does not record that it was attempted.
- Max attempts currently changes the status to `Cancelled`, which mixes automatic terminal failure with manual cancellation and blocks the existing retry action.
- There is no processing or claimed status, so two job queue sessions could process the same due entry at the same time.
- The outbox flow has no public enqueue API. Callers would need to insert outbox records directly and know which fields and BLOB helper behavior are required.
- The retry action does not clear error details, reset attempt count, or clearly define whether a retry is a continuation or a fresh attempt.
- Payload editing is available from the outbox list without checking whether the entry has already been sent or cancelled.
- `HttpClient.Send` result is ignored. Runtime send failures should become explicit processing errors with useful diagnostics.
- HTTP diagnostics are minimal. The outbox entry does not store endpoint, method, status code, response summary, duration, or correlation/idempotency data.
- If the HTTP call succeeds but inbox entry creation fails, the dispatcher may retry the outbound call and create a duplicate external side effect.
- Authentication is only an event hook; there is no auth profile table or secret storage yet.
- Setup validation is too small for operational use. It should also validate max attempts, retry delay, timeout, transport, auth requirements, and whether response processing is configured correctly.
- Automated tests are missing for the outbox eligibility rules, request building, successful dispatch, HTTP failure, retry scheduling, max attempts, manual retry/cancel, and response-to-inbox creation.

#### Suggested Starting Plan

1. Fix the BLOB helper first, then move payload and error write operations behind table-level procedures on `AMC Int. Outbox Entry`.
2. Fix `ShouldProcessEntry`: return `true` for eligible entries, reject future `Next Attempt At`, call `OnBeforeShouldProcessEntry`, and make setup lookup controlled.
3. Make failure persistence reliable in `AMC Outbox Dispatcher Job`, including missing setup, failed BLOB writes, attempt count, last attempt time, next attempt time, and terminal failure status.
4. Decide the outbox status model before adding more logic. At minimum, separate manual cancellation from max-attempt terminal failure, or add an explicit terminal failed status.
5. Add an enqueue procedure/codeunit that creates outbox entries consistently, writes the request payload, initializes status, and optionally stores source record and correlation data.
6. Harden the HTTP transport: handle `HttpClient.Send` returning false, keep timeout conversion explicit, and store useful request/response diagnostics without logging secrets.
7. Review the success path so `Attempt Count`, `Last Attempt At`, `Sent At`, and previous errors are updated consistently.
8. Protect against duplicate sends by adding a processing/claimed state or another concurrency control pattern before the HTTP call.
9. Rework response handling so a successful external call is not blindly repeated if inbox creation fails.
10. Add focused tests for the fixed outbox rules before implementing the inbox processor.

### Make Inbox Work

- Resolve duplicate object IDs in commented draft objects before enabling them.
- Finish and enable inbox processing, including response payload pages, error pages, retry logic, and final status handling.
- Add job queue setup guidance or assisted setup for the future inbox processor.
- Add automated tests for inbox response processing, retry behavior, failure handling, payload storage, and final status handling.

### Other

- Split shared queue statuses into separate inbox and outbox status enums if the workflows diverge.
- Implement authentication profile storage for secrets and connect it to `AMC Http Transport Default`.
- Add a cleanup job for deleting or archiving old inbox and outbox records.
- Add permissions, role center/search discoverability, and any required page actions for normal users.
- Add integration events or public APIs at the intended extension points once the core flow is stable.
