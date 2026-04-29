# Auth Subsystem

## Purpose and Position

Auth is a kernel-tier MEP subsystem. Its job is to produce a user context from whatever credentials — or absence of credentials — arrive with an incoming request. The user context is the artifact downstream code consumes to know who a request is from and what security posture applies to it.

Auth does not authorize. It does not decide whether a particular operation is permitted; it only produces the context that makes that decision possible. Authorization resolution is the Security subsystem's responsibility, consumed by RPC dispatch at the point of operation routing.

Auth does not transport. It does not own HTTP, Discord's gateway, MCP's protocol, or any other inbound or outbound wire format. Credentials arrive at Auth already extracted from whatever carried them; user contexts leave Auth as values, not responses. Transport is IoGateway's concern.

The boundary between Auth and its neighbors is narrow and deliberate. Auth is told about credentials; Auth reports who the credentials belong to.

## Dependencies

Auth consumes three peer subsystems through narrow contracts. These are the full set of Auth's external touch points; everything else is internal.

**IdentityServiceModule (kernel peer).** Owns platform identity infrastructure: the configuration of IDPs the platform integrates with (endpoints, client IDs, scopes, redirect URIs), the platform's own issuer-side surface (`.well-known` metadata, JWKS publication, DCR client registry when the platform acts as an OAuth2.1 authorization server for MCP). Auth reads from `identity_*` tables and the IdentityServiceModule contracts; Auth does not own any of this content. Provider and Protocol implementations in Auth receive their configuration from IdentityService at construction or invocation time. The design of IdentityServiceModule is out of scope for this spec; see `docs/identity_service.md`.

**Security (core peer).** Owns authorization — roles, entitlements, and the security decoration that rides on the user context. Auth consumes Security through the Security Context Provider contract (specified below). Auth invokes; Security decides. The decoration Security returns is opaque to Auth.

**Core Users (core peer).** Owns the internal user record. Auth consumes Users through the first-seen hook (specified below), invoking it when a normalized subject does not resolve to an existing user. Users mints the internal user GUID and records whatever claims it cares about.

Auth does not import internals from any of these subsystems. Each contract is a narrow surface declared by Auth (for Security and Users hooks) or by the peer (for IdentityService) and consumed through the agreed shape.

## Module Shape

Auth follows the kernel Manager/Executor/Provider pattern with one addition: Provider is paired with a sibling Protocol contract, and integrations implement both.

**AuthOperationsModule (Manager).** The input-dispatch surface. Operations decides, given whatever arrived with the request, which sequence of Executor verbs produces a valid user context. It is thin by design: the logic inside Operations is case-analysis over input shapes, not identity work.

**AuthExecutionModule (Executor).** The verb surface. Executor holds the work of extracting subjects, running IDP flows, resolving subjects to internal user GUIDs, managing sessions, and loading security context. Operations composes Executor verbs; Executor does not decide sequencing.

**Provider and Protocol (per-integration pair).** Each IDP integration contributes two implementations: a `BaseAuthProvider` that validates tokens and extracts normalized subjects, and a `BaseAuthProtocol` that manages the IDP-side lifecycle. They are paired at construction time — Protocol holds a reference to its Provider — and the pairing is mandatory for every integration.

## The User Context

"User context" refers to two distinct artifacts on opposite sides of the wire. Both carry user identity, but their scope and contents differ by design.

### Client-side user context

What the client holds. The client's storage typically contains three distinct tokens, only one of which is the platform's concern.

The platform-issued artifact is our session bearer token: a JWS we sign, containing an encrypted user GUID, which the client presents on every request. The client treats the token as opaque and does not unbundle it. The GUID inside is the client's identity claim; the JWS signature proves the token was issued by us; the session's salt (checked server-side) proves the token has not been revoked. All three must hold for the claim to be honored — the signature alone is not sufficient, and the GUID alone is meaningless without the signature.

Alongside our session token, the client typically also holds IDP-issued tokens — an IDP access token and an IDP refresh token — from whichever provider the user authenticated through. These are part of the IDP's refresh cycle, not the platform's session. They exist in client storage because the OAuth flow terminated there; our platform does not sign them, validate them, or depend on them after `complete_login` has produced a session. When the IDP access token expires, the client refreshes it against the IDP directly using the IDP's refresh token; that refresh cycle is independent of our session.

The client-side context is narrowly: our session bearer token. Nothing about the user's security posture, roles, entitlements, or claims is present on the client. The IDP tokens are adjacent artifacts the browser happens to hold; they are not part of the platform's user-context model.

### Server-side user context

What Auth produces and what downstream code — RPC dispatch, handlers, core modules — consumes. This is the artifact the rest of this spec describes. It is assembled by Operations on every request, lives for the duration of request handling, and is discarded when the request completes. It is never serialized to the client.

The server-side context is uniform in shape across all outcomes; what varies is which fields are populated and which variant applies.

**Anonymous.** No credentials were presented, or the credentials failed to resolve to a live session. The context carries the anonymous marker and no user identity. It is still a valid user context; downstream code treats anonymous as a first-class state rather than an error.

**Registered, no roles.** Credentials resolved to an internal user, but that user has no assigned roles or entitlements beyond public access. The user GUID is present; the security decoration reflects the empty posture.

**Decorated.** Credentials resolved to an internal user with roles and entitlements. The user GUID, session identifier, and security decoration are all populated.

At minimum, a server-side user context carries:

- The internal user GUID, or the anonymous marker.
- The session identifier the context was resolved through, when applicable.
- The security decoration returned by the Security Context Provider.
- A newly-issued bearer token, when the call that produced the context minted one (e.g., `complete_login`). This is the one case where something flows back toward the client — the new token is handed to the transport layer for delivery, and the server discards its reference once the response is on the wire.

The context is produced by Operations and consumed by RPC dispatch downstream. Auth does not inspect the security decoration; it carries it.

Credentials may arrive via HTTP, the MCP protocol, the Discord gateway, or any other transport IoGateway supports. The transport shapes how credentials are presented but does not shape the user context — the server-side context produced is the same shape regardless of where the credentials came from. Transport-shaped differences are resolved in Operations' input dispatch, not in the context.

## Operations Contract

Operations exposes three methods. Each has a clear input shape and a clear return type; callers choose based on what situation they are in.

**`resolve_user_context`.** The primary method. Accepts whatever credentials arrived with the request — a bearer token, an API token, MCP DCR credentials, or nothing — and returns a user context. The return is always a user context; there is no failure mode that returns something else. Invalid credentials resolve to anonymous (or to an explicit invalid signal within the context, if the RPC layer needs to distinguish "no credentials" from "bad credentials").

**`initiate_login`.** Called when a user action starts an IDP flow. Takes an integration identifier (which IDP) and whatever context the flow needs. Returns whatever the caller needs to continue the flow on the IDP side — typically a URL for redirect-based flows, but the shape is the Protocol's to define.

**`complete_login`.** Called when an IDP flow returns. Takes whatever the IDP handed back (a code, a callback payload, a DCR response) and produces a user context. This is where first-seen subjects become internal users, where sessions are minted, and where freshly-issued bearer tokens flow back to the caller via the user context.

Operations composes Executor verbs to fulfill each method. It does not talk to IDPs, query the database directly, or perform subject normalization. Its logic is case-analysis: given this input, run this sequence.

## Input Surface for `resolve_user_context`

The inputs Operations dispatches over fall into recognizable cases. The cases are a current inventory, not a closed set — new credential types slot in under the same principle.

**No credentials.** No session token, no API token, no DCR credentials. Operations returns an anonymous context directly; no Executor work is needed.

**Bearer token.** The credential the React client presents. Operations hands it to Executor for session resolution and security context loading; the result is the user context.

**API token.** A long-lived credential for service-to-service or programmatic access. Operations hands it to Executor; Executor's validation path differs from bearer tokens but the result — a user context — is the same shape.

**MCP DCR credentials.** A registered MCP client's credentials. Operations hands them to Executor; Executor resolves through the DCR-aware validation path and produces a user context.

The principle: every path terminates in a user context. Operations does not surface "auth failed" as a distinct return shape. A failed resolution is an anonymous context (or an anonymous context carrying an invalidity signal, depending on what RPC dispatch needs to distinguish). Callers always receive the same contract.

## Executor Responsibilities

Executor exposes verbs that Operations composes. Each verb is self-contained work; Executor does not know why it is being called in a particular order.

**Subject extraction.** Given an IDP token, drive the appropriate Provider to produce a normalized subject and claims bag. Executor selects the integration; Provider does the extraction.

**IDP flow management.** Given a flow-initiation request, drive the appropriate Protocol to start the flow. Given a flow completion, drive the Protocol to complete it. Protocol's Complete returns a normalized subject (because Protocol calls Provider internally); Executor receives that subject ready to use.

**Subject-to-user GUID resolution.** Given a normalized subject and its IDP identifier, resolve to the internal user GUID. When the subject is unknown, invoke the first-seen hook into core so an internal user is created; the resolution then proceeds against the newly-created user.

**Session handling.** Mint sessions, look them up, revoke them. Session management is internal to Executor's work; the user context surfaces only what callers need (session identifier, newly-issued bearer tokens where applicable). How sessions are stored, how bearer tokens are formatted, and how revocation is implemented are implementation details under this responsibility.

**Security context loading.** Given an internal user GUID, call the Security Context Provider to obtain the opaque decoration that rides on the user context. Executor does not inspect the decoration; it attaches it.

Executor is where IDP knowledge, database access, and kernel secrets meet. Operations is insulated from all of it; Provider and Protocol are insulated from session and security concerns.

## Provider and Protocol Contracts

Each IDP integration contributes two implementations, mandatorily paired at construction time. The pairing is explicit: `BaseAuthProtocol` is constructed with a reference to its corresponding `BaseAuthProvider`, and the integration's wiring establishes that pair.

### BaseAuthProvider

Takes an IDP token and returns a validated, normalized subject plus a claims bag.

The subject is normalized to the platform's canonical form before returning. Raw IDP-shaped identifiers do not leave Provider. The claims bag is passed through as the IDP reported it; Provider does not normalize claims, because claims are metadata consumed by the first-seen hook rather than a query surface.

Every integration implements Provider. There are no integrations where token validation is absent — even pure-bearer scenarios (API tokens validated against stored credentials) implement Provider, because the shape of "validate and produce subject" applies regardless of where the token came from.

### BaseAuthProtocol

Handles the IDP-side lifecycle of the integration. The surface covers:

- **Initiate.** Start an IDP flow. For OAuth-style integrations, this builds an authorization URL. For API-token integrations, this may be a self-test or a noop. For DCR, this triggers registration. The return is whatever the caller needs to continue on the IDP side.

- **Complete.** Finish an IDP flow. Receives whatever the IDP handed back (a code, a callback payload) and produces a normalized subject. Complete calls its paired Provider internally — the token the IDP returned is extracted into a subject before Complete's return, so Executor sees a validated subject, not a raw token.

- **Revoke-check.** Query the IDP for the current validity of a token or subject. For OAuth integrations with online validation, this is a live check. For offline-validated tokens, this may be a noop or a local validity assessment.

- **Link.** Associate a newly-authenticated subject with an existing internal user rather than minting a new user. Relevant for cases where a user adds a secondary IDP identity to their account.

Every integration implements Protocol. For integrations where an operation has no meaningful IDP-side work, the implementation reflects that — a noop is a valid implementation when the integration's mechanics don't require the operation. The contract requires the method; the integration decides what it means in context.

### Pairing

The pairing between Provider and Protocol is construction-time and per-integration. Microsoft's Protocol holds a reference to Microsoft's Provider; Google's Protocol holds a reference to Google's Provider. The coupling is mandatory and explicit in wiring; Executor's integration registry constructs them together and retrieves them together.

Complete and Refresh-style operations in Protocol call Provider internally; the pairing exists so that the IDP-specific token a Protocol operation produces is handed to the Provider that knows how to validate it. The pairing is not a composition pattern — Provider and Protocol remain separate contracts — but their relationship is coupled at the integration level, and the design says so.

## Subject Normalization

Every IDP subject is normalized to a canonical form before entering the database, logs, or any code path downstream of Provider. The canonical form is a UUID5 computed over `(idp_identifier, raw_subject)` using a kernel-secret namespace.

Three properties follow:

**Uniform storage shape.** Every stored subject is a UUID, regardless of which IDP produced it. The `auth_*` table that maps subjects to internal users has a single subject column of uniform width and type. No per-IDP parsing at query time.

**Breach-resistance across trust boundaries.** Recovering a raw IDP subject from a stored normalized subject requires the kernel-secret namespace, which is environment-resident and never DB-resident. A database leak alone does not expose IDP subjects; the attacker would also need the kernel secret.

**Consistency with platform conventions.** The UUID5 pattern is already how the platform handles deterministic identifiers per `database.md`. Subject normalization is one more application of the same pattern, not a new identifier shape.

Provider is responsible for performing the normalization. Raw IDP subjects are consumed inside Provider and do not appear in Provider's return value. Executor, the database, and all downstream consumers see only normalized subjects.

## Hook Surface to Core

When Executor encounters a normalized subject that does not resolve to an existing internal user, it invokes a first-seen hook into the core tier. The hook is Auth's way of letting core modules participate in account creation without Auth importing their internals.

Two core-tier hooks fire on first-seen:

- **Core Users.** Creates the internal user record. The user GUID is minted here (via `NEWID()` per `database.md`); Auth does not mint user GUIDs itself. The claims bag from Provider is passed through; Users decides which claims to persist and in what form.

- **Core Security.** Creates the default security posture for the new user. Auth does not know what the default posture is; Security owns that decision.

The hooks are invoked in order; Users runs first so the user GUID exists when Security needs it. Auth receives the resulting user GUID and proceeds with session minting and context assembly.

The hooks are the only surface through which core participates in Auth flows. Auth does not call core modules outside the first-seen path; core does not call Auth except through the Security Context Provider contract.

## Security Context Provider Contract

Auth declares an interface — the Security Context Provider — that the Security subsystem implements. The interface is Auth's way of asking "what security state applies to this user" without knowing anything about roles, entitlements, or how Security resolves them.

The contract:

- **Input.** An internal user GUID.
- **Output.** An opaque security decoration, attached to the user context and consumed by RPC dispatch downstream.

Auth does not inspect the decoration. Its shape, fields, and semantics are Security's concern; for Auth it is a value that rides on the user context from resolution through consumption.

The contract is identity-scoped: the decoration is resolved per user context resolution and reused across the request's operations. RPC dispatch performs per-operation entitlement checks using the decoration; the resolution itself happens once, not per-operation. An identity-scoped contract keeps Auth's work bounded and lets Security produce whatever shape makes its authorization decisions efficient.

Security's implementation of the contract is its own design problem, specified in `docs/security.md`. Auth's only commitment is to call the contract when a user context is being assembled and to attach the result.

## Token Model

Auth handles three categories of token, each with a distinct role.

**IDP tokens.** Tokens issued by external identity providers — access tokens, identity tokens, refresh tokens. They are transient from the platform's perspective: received during Protocol's Complete, consumed by Provider to produce a subject, and generally not surfaced to code outside Provider and Protocol. Their handling is internal to the integration.

**Bearer tokens.** The credential the platform issues to clients. Opaque to the client (the client does not decode them for meaning), they carry a session reference that resolves server-side to a session record and, through that, to a user. Bearer tokens are the platform's, not any IDP's; their format, signing, and lifecycle are platform-controlled.

**API tokens and MCP DCR credentials.** Alternate input types that Operations dispatches over. They resolve to user contexts through the same Executor verbs; only the validation path differs.

The specifics of how sessions are represented, how bearer tokens are minted and validated, and how revocation is implemented are implementation concerns under Executor's session-handling responsibility. The contracts defined in this spec do not depend on those specifics; a change to session storage or token format is internal to Executor.

## Auth Kernel Secrets

Auth depends on two kernel-tier secrets. Both are environment-resident and loaded at kernel startup; neither is DB-resident.

**JWT signing key.** Used to sign bearer tokens. Token validation requires this key; forging a token requires possession of it. Its blast radius on compromise is global — every outstanding bearer token becomes forgeable — which is why it lives outside the database and outside the rotatable service-tier secret surface.

**Subject normalization namespace.** The UUID5 namespace used for canonicalizing IDP subjects. Its blast radius on compromise is narrower: a combined DB-plus-namespace leak would expose raw IDP subjects for stored users. It lives in the environment for the same reason — defense in depth across trust boundaries.

These secrets are distinct from service-tier secrets stored in `system_configuration`. Service-tier secrets (external API keys, third-party credentials, IDP client secrets) are runtime-rotatable through the platform's secret-maintenance surface; their exposure is remediable by rotation. Kernel secrets are not runtime-rotatable in the same sense — rotating the JWT signing key invalidates every outstanding bearer token globally, and rotating the subject namespace invalidates every stored subject mapping. The distinction reflects blast radius, and the two tiers are handled separately by design.

IDP client secrets — the credentials Auth's integrations use to authenticate to external IDPs — are explicitly service-tier. They are referenced from `identity_*` provider-configuration rows and resolved through `system_configuration` at use. A leaked IDP client secret is remediated by rotation at the IDP and an update to `system_configuration`; the blast radius is bounded to that single integration. The kernel-tier list does not grow per-integration; it is short by design and stays short.

## Storage Orientation

Auth's storage spans three concept clusters per the platform's naming conventions, plus one peer cluster it reads from but does not own.

**`account_*`.** Authoritative identity data. The account user record itself, the account's assigned roles and entitlements, and the account's IDP links. These are durable properties of the account, not ephemeral auth state. The IDP link table — mapping `(idp_identifier, normalized_subject)` to an internal user GUID — lives here because the links define the account's external identities.

**`users_*`.** Join tables for user-to-thing relationships. These tables provide navigational consistency: queries starting from a user find related artifacts through the `users_*` cluster regardless of where the target tables live. The cluster is consistent-by-convention — user-to-thing relationships get `users_*` mapping tables even when the join row carries no metadata beyond the foreign keys, because the consistency makes the schema legible.

**`auth_*`.** Auth's operational tables. Sessions and token records live here; these are tables Auth reads and writes during its work. They are not authoritative identity data — they are the operational state that lets Auth do its job.

**`identity_*` (peer, read-only from Auth's perspective).** Owned by IdentityServiceModule. Holds IDP provider configuration, the platform's issuer-side metadata, and the DCR client registry. Auth reads from this cluster when Provider and Protocol implementations need their integration's configuration, but does not write to it. See `docs/identity_service.md` for the cluster's structure.

Cross-cluster references use `ref_*` columns per `database.md`. The cluster layering is a platform-wide convention, specified in the database documentation; this spec only notes which clusters Auth occupies and which it consumes.

## Provider Sub-families

Integrations are characterized by the shape of their Provider and Protocol implementations. OAuth-style integrations share mechanics — authorization URLs, code exchange, token validation against a JWKS — and their implementations look similar. Non-OAuth integrations (API tokens, DCR) have different mechanics but implement the same contracts.

The principle: new integration types justify contract extensions rather than distortions of existing contracts. If a future integration's lifecycle genuinely does not fit the Initiate/Complete/Revoke-check/Link surface, the response is to extend the contract or define a parallel one — not to force-fit the integration into methods that don't apply.

The current inventory of integrations is not a closed set, and sub-families are not a fixed taxonomy. They are a way of recognizing that integrations cluster by mechanics, and that the clustering is useful for implementation even though it is not load-bearing in the architecture.
