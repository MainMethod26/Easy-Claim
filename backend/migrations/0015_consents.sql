-- Migration 0015: POPIA consent / mandate forms.
--
-- After the insurer has checked a customer's documents (policy-link onboarding, or claim Verify),
-- the customer is sent a consent form written by that insurer. The customer signs it electronically
-- (typed full name + password re-entry, ECTA ordinary electronic signature); the server seals the
-- signed record with ML-DSA-65. Approval (onboarding) and Screening (claims) wait for a signature.
-- The customer can withdraw consent later (POPIA s11(2)(b)); further work on that subject then stops.
--
-- consent_templates: each insurer's own wording, one row per saved version (never edited).
-- consents: one form per subject. The text sent is copied in (body + sha256) so later template
--           edits never change what a customer saw or signed. Signed fields are write-once.

CREATE TABLE IF NOT EXISTS consent_templates (
    id TEXT PRIMARY KEY,
    tenant_id TEXT NOT NULL REFERENCES tenants(id),
    kind TEXT NOT NULL CHECK (kind IN ('onboarding', 'claim')),
    version INTEGER NOT NULL CHECK (version >= 1),
    body TEXT NOT NULL,
    created_by TEXT NOT NULL,
    created_at TEXT NOT NULL,
    UNIQUE (tenant_id, kind, version)
);

CREATE TRIGGER IF NOT EXISTS consent_templates_no_update BEFORE UPDATE ON consent_templates
BEGIN SELECT RAISE(ABORT, 'consent_templates is append-only'); END;
CREATE TRIGGER IF NOT EXISTS consent_templates_no_delete BEFORE DELETE ON consent_templates
BEGIN SELECT RAISE(ABORT, 'consent_templates is append-only'); END;

CREATE TABLE IF NOT EXISTS consents (
    id TEXT PRIMARY KEY,
    tenant_id TEXT NOT NULL REFERENCES tenants(id),
    user_id TEXT NOT NULL REFERENCES users(id),
    subject_type TEXT NOT NULL CHECK (subject_type IN ('policy_link', 'claim')),
    subject_id TEXT NOT NULL,
    -- 0 = the built-in EasyClaim starter text (the insurer had not saved its own yet).
    template_version INTEGER NOT NULL,
    body TEXT NOT NULL,
    body_sha256 TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'signed', 'declined', 'withdrawn', 'superseded')),
    requested_by TEXT NOT NULL,
    requested_at TEXT NOT NULL,
    signed_name TEXT,
    signed_at TEXT,
    signature_alg TEXT,
    signature_key_id TEXT,
    record_sha256 TEXT,
    signature TEXT,
    responded_at TEXT,
    response_reason TEXT,
    CHECK ((status IN ('signed', 'withdrawn')) = (signed_at IS NOT NULL) OR status = 'superseded')
);

-- At most one open (pending or signed) form per subject.
CREATE UNIQUE INDEX IF NOT EXISTS idx_consents_open ON consents(subject_type, subject_id) WHERE status IN ('pending', 'signed');
CREATE INDEX IF NOT EXISTS idx_consents_user ON consents(user_id, requested_at);
CREATE INDEX IF NOT EXISTS idx_consents_subject ON consents(subject_type, subject_id, requested_at);

-- What was sent and what was signed can never change; a form is never deleted.
CREATE TRIGGER IF NOT EXISTS consents_text_fixed BEFORE UPDATE OF id, tenant_id, user_id, subject_type, subject_id, template_version, body, body_sha256, requested_by, requested_at ON consents
BEGIN SELECT RAISE(ABORT, 'consent text and subject are fixed'); END;
CREATE TRIGGER IF NOT EXISTS consents_signature_once BEFORE UPDATE OF signed_name, signed_at, signature_alg, signature_key_id, record_sha256, signature ON consents
WHEN OLD.signed_at IS NOT NULL
BEGIN SELECT RAISE(ABORT, 'a signature cannot be changed'); END;
CREATE TRIGGER IF NOT EXISTS consents_no_delete BEFORE DELETE ON consents
BEGIN SELECT RAISE(ABORT, 'consents cannot be deleted'); END;
