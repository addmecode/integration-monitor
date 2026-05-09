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
| `AMC Int. Message Setup` | Page 50116 | Active | Administration list page for maintaining integration message setup records. It exposes the key processing, endpoint, retry, and transport settings. |
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

## TODO

- Make the project compile and run end to end in Business Central.
- Resolve duplicate object IDs in commented draft objects before enabling them.
- Finish and enable inbox processing, including response payload pages, error pages, retry logic, and final status handling.
- Split shared queue statuses into separate inbox and outbox status enums if the workflows diverge.
- Implement a reliable outbox enqueue API instead of creating outbox records manually.
- Review and fix outbox eligibility checks, retry timing, max attempt handling, and status transitions.
- Replace temporary TODO logic in `AMC Outbox Processor` with a clearer processing flow and dedicated failure handling.
- Add robust persistence for error text and call stack details, preferably through table-level helper procedures.
- Implement authentication profile storage for secrets and connect it to `AMC Http Transport Default`.
- Add a cleanup job for deleting or archiving old inbox and outbox records.
- Add setup validation for required fields such as endpoint URL, max attempts, retry delay, timeout, and transport.
- Add job queue setup guidance or assisted setup for the dispatcher and future inbox processor.
- Add automated tests for setup validation, outbox dispatch, retry behavior, failure handling, payload storage, and inbox creation.
- Add permissions, role center/search discoverability, and any required page actions for normal users.
- Add integration events or public APIs at the intended extension points once the core flow is stable.
