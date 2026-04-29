# Security Subsystem

## 1. Purpose and Position

Security is a core-tier MEP subsystem. It produces authorization primitives - the security decoration that rides on a user context and the evaluation function that decides whether a user clears a given requirement.

Security does not authenticate. Identity resolution is Auth's responsibility; Security receives a resolved internal user GUID and answers what that user is authorized to do.

Security does not own op definitions. The RPC operation registry declares what roles and entitlements each op requires; Security consumes those requirements through evaluation calls. Security owns the decoration and the check; it does not own the requirements or the ops.

It is worth calling out that the RPC system is not currently being implemented — it is the engine's client-facing dispatch layer, and as of this writing we are still building the data engine. The security posture is defined, but enforcement will not be wired for some time. This subsystem regulates operation dispatch to the API surface of the engine.

## 2. Dependencies

Security consumes two peer subsystems through narrow contracts.

**Auth (kernel peer).** Security implements the Security Context Provider contract that Auth declares. Auth invokes Security on every user context assembly; Security returns the decoration. Security also receives first-seen invocations from Auth when a new internal user is created, at which point Security establishes the user's default posture.

**Database (kernel peer).** Security reads and writes its role, entitlement, and join tables through the standard database contract.

Security has no dependency on RPC dispatch or on any transport. RPC consumes Security; Security does not know that RPC exists.

## 3. Module Shape

Security follows the core-tier Manager/Executor pattern.

**SecurityOperationsModule (Manager).** The public surface consumed by peers. Implements the Security Context Provider contract Auth invokes. Exposes the evaluation primitive consumers use to check a decoration against a requirement.

**SecurityExecutionModule (Executor).** The verb surface. Handles role and entitlement resolution against the database, default-posture creation on first-seen, and decoration assembly.

Security mediates no external resource and does not carry a Provider layer.

## 4. Roles

A role corresponds one-to-one with an RPC domain. A domain is the first segment of an op URN (the `domain` in `urn:domain:subdomain:verb_noun:version`). Each domain is gated by exactly one role; each role gates exactly one domain. Holding the role is the necessary and sufficient condition for clearing the domain check.

Domains are singular — a domain name appears at only one place in the URN space.

User-to-role is many-to-many. A user may hold multiple roles; a role may be held by multiple users.

## 5. Entitlements

An entitlement corresponds one-to-one with an RPC subdomain name. A subdomain is the second segment of an op URN. Each entitlement gates every op whose subdomain segment carries the entitlement's name, regardless of which domain the op sits under.

Subdomain names recur across domains. The same subdomain name under two different domains names the same entitlement - the entitlement gates the subdomain half, and the domain's role gates the domain half, independently. Any specific op is reachable only when both halves clear.

An entitlement is boolean: present on a user's decoration or absent. There are no graded values.

Entitlements are explicit grants to users, independent of roles. A user's security context is the aggregation of all roles and all entitlements assigned to the user; the two sets are joined at evaluation time to gate access to RPC calls but are managed separately.

## 6. The Security Decoration

The decoration is what SecurityOperationsModule returns to Auth in response to a Security Context Provider call. It carries:

- The user GUID the decoration was resolved for.
- The user's assigned roles, by role identifier.
- The user's assigned entitlements, by entitlement identifier.

The decoration is identity-scoped per Auth's contract — resolved once per user context assembly, reused across the request's operations. It is opaque to Auth and structured for efficient evaluation by consumers.

## 7. Authorization Resolution

Resolution is the work SecurityExecutionModule performs when the Security Context Provider is called. The decoration is produced by a single query that joins the user against the role and entitlement assignment tables and returns the aggregated result as one object.

The anonymous user has no roles and no entitlements; resolution returns an empty decoration.

## 8. Evaluation Against Requirements

SecurityOperationsModule exposes an evaluation primitive: given a decoration and a requirement, does the user clear?

A requirement is derived from an op URN. The `domain` segment names the role the user must hold; the `subdomain` segment names the entitlement the user must have. The user clears the requirement when the named role is present in the decoration's assigned roles AND the named entitlement is present in the decoration's assigned entitlements.

URN segments named `public` are always cleared — see §9. This is how ungated access is expressed; the rule is uniform, and `public` is the reserved name that bypasses the corresponding check.

The evaluation is a pure function of the decoration and the requirement. Security does not fetch the requirement; the caller supplies it.

## 9. The `public` Convention

public is a first-class segment name, reserved at the URN level. It is neither a role nor an entitlement; it is the name the evaluation primitive recognizes to mean "no check applies to this segment." Recognition is segment-local — a public domain segment bypasses the role check, a public subdomain segment bypasses the entitlement check, and the two are independent.
The four combinations follow directly:

- urn:public:public:... - fully ungated. Cleared for any user, including anonymous. This is how truly public ops (version banner, health check) are expressed.
- urn:<domain>:public:... - role-gated, entitlement-ungated. A user with the domain's role reaches the op regardless of their entitlement set. Example: urn:finance:public:get_trial_balance:1 — any user holding finance may read it.
- urn:public:<subdomain>:... - entitlement-gated, role-ungated. Reaches an entitlement-controlled op inside an otherwise-public domain. Rare; urn:public:storage:... is the canonical shape — the storage domain is public (the gallery is openly reachable), but ops under the file_manager subdomain are gated by the enable_storage entitlement.
- urn:<domain>:<subdomain>:... - both halves gated. The default and most common case.

Because public is recognized at the segment level rather than resolved as a role or entitlement identifier, it does not occupy a row in the role or entitlement tables. No public role exists; no public entitlement exists. The name is reserved against both identifier spaces to prevent collision.

## 10. Default Posture

When Auth's first-seen hook results in a new internal user, Security creates the user's default security posture: no roles, no entitlements. The user is registered but clears no role-gated or entitlement-gated requirements. Ops under `public` segments remain reachable.

Assignment of roles and entitlements beyond the default is a separate administrative concern and not part of the first-seen flow.

## 11. Storage Orientation

Security owns tables in the `account_*` cluster covering:

- Role definitions, each associated with its gated domain.
- Entitlement definitions, each associated with its gated subdomain.
- User-to-role assignments.
- User-to-entitlement assignments.

The op-to-requirement mapping is implicit in the op URN — the domain and subdomain segments name the role and entitlement that gate the op. The domain and subdomain definitions themselves live in the RPC operation registry, not in Security's tables. Security consumes requirements through evaluation calls; it does not own the op definitions.