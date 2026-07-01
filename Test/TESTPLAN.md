# Integration Monitor — Unit Test Plan

Tracking file for adding unit tests across multiple sessions.

**How to use (each session):**
1. Read this file. Pick the first unchecked `[ ]` item in the lowest-numbered unfinished phase.
2. Implement only one item. Run the test build.
3. Make code review of the changes you made.
4. Check it off `[x]`, add a short note if anything deviated from the description.
5. **Do not commit files.** Leave changes in the working tree for the user to review and commit.

**Conventions:**
- Test codeunits live in the `Test/` app (see Phase 0). `Subtype = Test`.
- Test procedure names in Given/When/Then style, one behavior per `[Test]` procedure.
- Prefer BC `Library - *` codeunits + the `Assert` codeunit. Use the `AMC Test Library` factory for setup data.
- Each test must be isolated and idempotent (no dependency on another test's leftover data).
- For expected `Error` calls, assert with `asserterror` + `Assert.ExpectedError`.

---

## Phase 0 — Scaffold test app (BLOCKS everything)

> **Status:** Both apps **compile green locally** (alc 17.0, packagecache from container symbols). Test-runner *execution* of the smoke test still needs a container/CI run (no sandbox run done locally). User downloaded symbols and dropped `Tests-TestLibraries` from the deps (unused by current code).

- [x] **Create the `Test/` app project.** `Test/app.json` created (id `0a210a97-…`, range 50141–50180, runtime 16.0, `NoImplicitWith`+`TranslationFile`). Deps: Integration Monitor + Library Assert + Any + Test Runner. *(`Tests-TestLibraries`/`System Application Test` omitted — not needed by current code; add when a test needs `Library - *`.)* Feature folders mirrored under `Test/src/` as phases land (`Helpers/` added).
- [x] **Register the test folder with AL-Go.** `.AL-Go/settings.json`: `testFolders: ["Test"]`, and `appFolders: ["integration-monitor"]` set explicitly so auto-discovery doesn't misclassify the two app folders.
- [x] **Add a smoke test.** `AMC Smoke Test` (50141) written and **compiles green**. Run-green to be confirmed by the AL-Go pipeline / a container run.
- [x] **Add the `AMC Test Library` factory codeunit.** `AMC Test Library` (50142) with `CreateMessageSetup`/`CreateOutboxEntry`/`CreateInboxEntry`/`CreateAuthProfile`/`WriteBlobText` + `EnsureMessageSetup` helper. Uses `Any` for don't-care values. Compiles green.
- [x] **Add a mock HTTP transport for processor send-path tests.** `AMC Int. Transport Type` was **already `Extensible = true`** (no production change needed). Added: `AMC Mock Transport Type` enumext (50145, value `Mock`=50141) → `AMC Mock Http Transport` (50144) implementing `AMC IHttpTransportHandler`, fed by single-instance `AMC Mock Transport State` (50143). ⚠ **Mock can set the response BODY but NOT the status code** — AL has no setter for `HttpResponseMessage.HttpStatusCode` (get-only built-in). A fabricated response always reports non-success, so the mock only drives the **failure** path of `ValidateResponse`. **See revised Phase 6 note for the success-path mechanism.**
- **Production change:** added `internalsVisibleTo` for the test app in `integration-monitor/app.json` so Phase 5/6 can reach `internal` processor procedures.

## Phase 1 — Blob Helper (`AMC Int. Blob Helper`, 50113) → `AMC Blob Helper Tests`

- [x] **Text BLOB round-trips.** Given a record with a BLOB field, when `WriteTextToBlob` stores a known string and `ReadBlobAsText` reads it back, then the returned text equals the original (including non-ASCII to confirm UTF-8).
- [x] **JSON BLOB parses.** Given a BLOB written with a serialized `JsonObject`, when `ReadBlobAsJsonObject` reads it, then the resulting `JsonObject` contains the expected properties/values.
- [x] **Temp Blob round-trips.** Given a `Temp Blob`, when `WriteTextToTempBlob` writes text, then reading the temp blob back (via an InStream created from it) returns the same text. Guards the documented InStream/Temp-Blob lifetime gotcha.
- [x] **Non-BLOB field is rejected.** Given a RecordRef and a field number that is not a BLOB, when `ReadBlobAsText` / `WriteTextToBlob` is called, then it errors with the "must be a BLOB field" message (`TestBlobField`).

## Phase 2 — Outbox Entry Mgt (`AMC Outbox Entry Mgt.`, 50119) → `AMC Outbox Entry Mgt Tests`

- [x] **EnqueueEntry creates a ready entry.** Given a message type, a payload `Temp Blob`, and a source RecordId, when `EnqueueEntry` runs, then a new Outbox row exists with `Status = ReadyToProcess`, `Request Payload` equal to the supplied payload, `Source Record ID` set, and the returned value equals the new `Entry No.`.
- [x] **OnInsert defaults timestamps.** Given a new Outbox entry inserted with `Created At`/`Next Attempt At` left as `0DT`, when inserted, then both are set to (approximately) `CurrentDateTime`. Given they are pre-set, then they are left unchanged.
- [x] **ResetEntry is blocked for terminal/in-flight statuses.** Given an entry with `Status` = Processed, Sending, or ResponseReceived, when `ResetEntry` runs, then it errors with "Cannot reset entry with status = %1" and nothing changes (one test per status).
- [x] **ResetEntry clears retry state otherwise.** Given an entry with `Status` = Failed (with non-zero Attempt Count, a Last Error, a Response Payload, and timestamps set), when `ResetEntry` runs, then `Status = ReadyToProcess`, `Attempt Count = 0`, `Next Attempt At` ≈ now, and `Last Attempt At`/`Processed At`/`Response Received At`/`Last Error`/`Response Payload` are cleared.
- [x] **CancelEntry sets Cancelled and is idempotent.** Given a ReadyToProcess entry, when `CancelEntry` runs, then `Status = Cancelled`. Given an already-Cancelled entry, when `CancelEntry` runs again, then it stays Cancelled and does not error.
- [x] **OnDelete is blocked while Sending.** Given an Outbox entry with `Status = Sending`, when deleted, then it errors with "Cannot delete record because the outbox entry is being sent."
- [x] **OnDelete is blocked when a related Inbox entry is Processing.** Given an Outbox entry with a related Inbox entry (`Outbox Entry No.` matches) whose `Status = Processing`, when the Outbox entry is deleted, then it errors with "Cannot delete record because a related Inbox Entry is being processed."
- [x] **OnDelete cascades to related Inbox entries otherwise.** Given an Outbox entry (not Sending) with related Inbox entries in non-Processing statuses, when deleted, then all Inbox entries with that `Outbox Entry No.` are removed.

## Phase 3 — Inbox Entry Mgt (`AMC Inbox Entry Mgt.`, 50126) → `AMC Inbox Entry Mgt Tests`

- [x] **OnInsert defaults timestamps.** Given a new Inbox entry with `Created At`/`Next Attempt At` = `0DT`, when inserted, then both default to ≈ now; pre-set values are left unchanged.
- [x] **OnDelete is blocked when a related Outbox entry exists.** Given an Inbox entry whose `Outbox Entry No.` references an existing Outbox row, when the Inbox entry is deleted, then it errors with "Cannot delete record because related outbox entry exists." Given `Outbox Entry No. = 0`, then deletion is allowed.
- [x] **ResetEntry is blocked for Processed/Processing.** Given an Inbox entry with `Status` = Processed or Processing, when `ResetEntry` runs, then it errors with "Cannot reset entry with status = %1" (one test per status).
- [x] **ResetEntry clears retry state otherwise.** Given a Failed Inbox entry with non-zero Attempt Count, Last Error, and timestamps, when `ResetEntry` runs, then `Status = ReadyToProcess`, `Attempt Count = 0`, `Next Attempt At` ≈ now, and `Last Attempt At`/`Processed At`/`Last Error` are cleared.
- [x] **CancelEntry sets Cancelled and is idempotent.** Given a ReadyToProcess Inbox entry, when `CancelEntry` runs, then `Status = Cancelled`; running again leaves it Cancelled without error.

## Phase 4 — Failure handlers (`AMC Outbox Failure Handler` 50118 / `AMC Inbox Failure Handler` 50128) → `AMC Outbox Failure Tests` / `AMC Inbox Failure Tests`

The failure handlers run via `OnRun` against a record after an error; drive them through `Codeunit.Run` with a simulated last error, or call the marking flow directly.

- [x] **Failure increments attempt count and marks Failed.** Given an entry with `Attempt Count = N` and a Message Setup with `Max Attempts > N+1`, when the failure handler runs, then `Attempt Count = N+1`, `Last Attempt At` ≈ now, `Processed At = 0DT`, and `Status = Failed`.
- [x] **Next Attempt At applies linear backoff under Max Attempts.** Given the resulting `Attempt Count < Max Attempts` and `Base Retry Delay (sec) = D`, when the handler runs, then `Next Attempt At = Last Attempt At + D*1000 ms`.
- [x] **Next Attempt At stays empty at/over Max Attempts.** Given the resulting `Attempt Count >= Max Attempts`, when the handler runs, then `Next Attempt At = 0DT` (no further retry scheduled).
- [ ] **Last Error blob is populated.** Given a failure with a known error text/call stack, when the handler runs, then the `Last Error` BLOB contains the formatted "Error:…\Call Stack:…" message.
- [ ] **(Outbox only) status is preserved when response already received.** Given an Outbox entry with `Status = ResponseReceived` at failure time, when the handler runs, then `Status` is NOT overwritten to Failed (the received response is retained), while attempt count and Last Error still update.

## Phase 5 — Processor should-process rules (`AMC Outbox Processor` 50116 / `AMC Inbox Processor` 50127)

Drive `DoShouldProcessEntry` through the public `Run` path. "Skip" = the entry's status/attempt fields are unchanged after running (no claim, no processing).

- [ ] **Skip when the message setup is disabled.** Given `IntMessageSetup.Enabled = false`, when the processor runs the entry, then the entry is left untouched.
- [ ] **Skip when status is not eligible.** Given an entry whose `Status` is outside the allowed set (Outbox: ReadyToProcess/Failed/ResponseReceived; Inbox: ReadyToProcess/Failed), e.g. Cancelled or Processed, when run, then it is skipped.
- [ ] **Skip when Next Attempt At is in the future.** Given `Next Attempt At > now`, when run, then the entry is skipped (retry delay not yet elapsed).
- [ ] **Skip when attempts are exhausted.** Given `Attempt Count >= Max Attempts`, when run, then the entry is skipped.
- [ ] **(Inbox) ClaimForProcessing transitions to Processing.** Given an eligible Inbox entry, when claimed, then `Status = Processing` and a re-read confirms the lock-and-set committed; a second claim attempt on a non-eligible status returns false.
- [ ] **(Inbox) MarkInboxAsProcessed finalizes the entry.** Given a claimed Inbox entry whose handler succeeds, when marked processed, then `Status = Processed`, `Processed At` ≈ now, `Last Attempt At` ≈ now, and `Attempt Count` incremented by 1.
- [ ] **(Outbox) ResponseReceived path creates an Inbox entry and completes.** Given an Outbox entry with `Status = ResponseReceived` and a stored Response Payload, when processed, then a new Inbox entry is created (`Outbox Entry No.`, `Message Type`, `Source Record ID`, `Status = ReadyToProcess`, copied Response Payload) and the Outbox entry is marked Processed.
- [ ] **(Outbox) ValidateResponse maps HTTP status to success/error.** Given a success status code, when `ValidateResponse` runs, then no error. Given a non-success status code with a body, then it errors with "HTTP request failed with status %1" including the response body.

## Phase 6 — Processor send-path (`AMC Outbox Processor`, 50116) — needs the Phase 0 mock transport

> ⚠ **Mock-transport limitation (found in Phase 0):** `HttpResponseMessage.HttpStatusCode` is get-only in AL — the mock transport cannot fabricate a 2xx response, so it only exercises the **failure** path (`ValidateResponse` errors on non-success). For the **success** path, pick one in Phase 6: (a) mock the real `HttpClient` used by `AMC Http Transport Default` via BC's HttpClient test handler so a genuine 200 is produced; (b) split the success-path assertions to drive `ProcessReceivedResponse`/`StoreResponseAndCreateInboxEntry` directly with a pre-seeded `Response Payload` + `Status = ResponseReceived` (covered by Phase 5's ResponseReceived test); or (c) extend `AMC IHttpTransportHandler` so the mock returns an outcome object instead of a raw `HttpResponseMessage`. Decide before writing the first Phase 6 test.

- [ ] **Successful send completes and (optionally) stores the response.** Given an eligible Outbox entry and a Message Setup whose `Transport` is the mock returning HTTP 200, when processed: with `Process Response = true`, the Response Payload is stored, `Status = ResponseReceived`, and an Inbox entry is created; with `Process Response = false`, no Inbox entry is created and the entry is marked Processed.
- [ ] **Failing send routes through the failure handler.** Given the mock returns HTTP 500, when the entry is processed via `AMC Outbox Entry Mgt.ProcessEntry`, then `ValidateResponse` errors, the failure handler runs, and the entry ends `Status = Failed` with `Last Error` populated.
- [ ] **ClaimForSending only claims eligible entries.** Given an entry with `Status` = ReadyToProcess or Failed, when claimed for sending, then `Status = Sending` (committed). Given any other status, then the claim returns false and the entry is not modified.

## Phase 7 — Auth (`AMC Int. Auth Profile Mgt.` 50120 / Basic 50134 / Bearer 50135 / Auth Applier 50121)

- [ ] **SetSecret rejects empty and records audit.** Given a profile with a Code, when `SetSecret` is called with an empty `SecretText`, then it errors "The secret value cannot be empty." When called with a real secret, then `Has Secret = true`, `Secret Updated At` ≈ now, and `Secret Updated By = UserId`.
- [ ] **DeleteSecret clears the secret and audit.** Given a profile with a stored secret, when `DeleteSecret` runs, then the secret store no longer has it, `Has Secret = false`, and `Secret Updated At`/`Secret Updated By` are cleared.
- [ ] **Changing Auth Type deletes the stored secret.** Given a profile with a secret and Auth Type = Basic, when `Auth Type` is validated to Bearer, then the stored secret is deleted (a stale secret cannot survive a type switch).
- [ ] **Renaming a profile with a secret is blocked.** Given a profile that `HasSecret`, when its `Code` is renamed, then it errors "…cannot be renamed because it has a stored secret." Renaming a profile without a secret succeeds.
- [ ] **ClearSecretWithEnabledSetupCheck disables dependent setups on confirm.** Given a profile referenced by N enabled `AMC Int. Message Setup` records, when `ClearSecretWithEnabledSetupCheck` runs and the Confirm is answered yes (confirm handler), then those setups are set `Enabled = false` and the secret is cleared. When answered no, then nothing changes.
- [ ] **TestProfile requires Code, type-specific fields, and a secret.** Given a profile with no stored secret, when `TestProfile` runs, then it errors "…does not have a stored secret." Given a Basic profile with no Username, then `ValidateProfile` errors via `TestField(Username)`.
- [ ] **Basic handler builds the Authorization header.** Given a Basic profile with Username and a stored password, when `ApplyAuth` runs, then the request carries `Authorization: Basic <base64(username:password)>`. Given the request already has an Authorization header, then it is replaced (not duplicated).
- [ ] **Basic handler ValidateProfile requires Username.** Given a Basic profile with a blank Username, when `ValidateProfile` runs, then it errors via `TestField(Username)`.
- [ ] **Bearer handler builds the Authorization header.** Given a Bearer profile with a stored token, when `ApplyAuth` runs, then the request carries `Authorization: Bearer <token>`, replacing any existing Authorization header.
- [ ] **Auth Applier handles empty and missing profiles.** Given `AuthProfileCode = ''`, when `ApplyAuth` runs, then it is a no-op (no header, no error). Given a non-existent code, then it errors "Authentication profile %1 does not exist."

## Phase 8 — Setup + Message Mgt (`AMC Int. Message Setup Mgt.` 50122 / `AMC Message Mgt.` 50125)

- [ ] **Cleanup date formula must resolve before today.** Given `Delete Outbox Entr. Older Than` blank, when validated, then no error. Given a formula that resolves to today or a future date, then `FieldError` "must calculate to a date before today". Given a formula resolving to a past date (e.g. `-1D`), then no error.
- [ ] **Enabling a setup validates transport and auth.** Given a setup with an invalid/blank `Endpoint URL`, when `TestRequiredFieldsForEnabled` runs, then the transport handler errors ("The URL in %1 field is not valid" / missing URL). Given an `Auth Profile Code` whose profile lacks a secret, then it errors via the auth profile check. Given a valid endpoint and a fully configured auth profile, then no error.
- [ ] **GetMessageSetup errors when the setup is missing.** Given a message type with no `AMC Int. Message Setup` row, when `GetMessageSetup`/`TestMessageSetupExists` runs, then it errors "Integration message setup for message type %1 does not exist." Given an existing setup, then it returns it without error.

## Phase 9 — Demo PostCode (`AMC Post Code Validation Mgt` 50123 / `AMC Post Code Valid Msg Hdlr` 50124)

- [ ] **BuildValidationPayload emits the expected JSON.** Given a Post Code with Code and Country/Region Code, when the validation payload is built (exercised via `EnqueueValidation`), then the stored request payload is JSON with `code` and `countryRegionCode` set to those values.
- [ ] **EnqueueValidation creates an Outbox entry and marks the Post Code Sent.** Given a Post Code with Code and Country/Region Code, when `ValidatePostCode` runs, then a new Outbox entry exists with `Message Type = AMCPostalCodeValidation` and `Source Record ID` = the Post Code, and the Post Code `AMC Validation Status = Sent`. Given a Post Code missing Code or Country/Region Code, then it errors via `TestField`.
- [ ] **ResetValidation removes pending entries and clears status.** Given a Post Code with Outbox entries in ReadyToProcess/Cancelled (and some in other statuses), when `ResetValidation` runs, then only the ReadyToProcess/Cancelled entries for that source record are deleted and `AMC Validation Status` is set to blank ` `.
- [ ] **GetValidationStyle maps status to a style.** Valid → `Favorable`, Invalid → `Unfavorable`, any other status → `''` (one assertion per branch).
- [ ] **UpdateValidationAudit sets/clears audit fields.** Given status set to blank ` `, when `UpdateValidationAudit` runs, then `AMC Validated At`/`AMC Validated By` are cleared. Given a non-blank status, then they are set to ≈ now / current user.
- [ ] **BuildRequestUri trims trailing slash and escapes the where-clause.** Given an Endpoint URL with a trailing `/` and a country/post code, when the request URI is built, then there is no double slash and the `where=` query value is URI-escaped (`country_code="XX" AND postal_code="YY"`).
- [ ] **ResponseMatchesPostCodeDetails matches case/space-insensitively.** Given a response `results` array whose entry matches the Post Code's country, postal code, county, and place/admin name after normalization (uppercase, spaces stripped), then it returns true. Given no match or an empty `results` array, then it returns false. Include a `NormalizeValue` case to confirm `' ny '` matches `'NY'`.

---

## Decisions / gotchas
- **Order:** Phase 0 blocks everything. After it, Phases 1–5 and 7–9 are independent. Phase 6 depends on the Phase 0 mock transport.
- **Secrets:** auth handlers use `[NonDebuggable]` + `SecretText`. Assert on the resulting header value, never read the secret back directly.
- **UI calls:** procedures using `Confirm`/`Message` (e.g. `ClearSecretWithEnabledSetupCheck`, `ViewErrorDetails`) need `[HandlerFunctions]` confirm/message handlers; `ViewPayload`/`EditPayload` open a page (`RunModal`) and are out of unit-test scope.
- **Commit/lock:** several processor procedures call `Commit`; run them through `Codeunit.Run` so the test transaction model behaves as in production.
- **Production change in Phase 0:** `AMC Int. Transport Type` enum must become `Extensible = true` to register the mock transport. Flag it explicitly in that commit.
