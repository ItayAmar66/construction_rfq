# Admin tools

Firebase Admin scripts for Construction RFQ (`construction-rfq-itay-20-2eee0`).

## Setup

```bash
cd tools/admin
npm install
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/serviceAccount.json"
# or: gcloud auth application-default login
```

## Manual QA reset

| Script | Purpose |
|--------|---------|
| `manual_qa_inspect.js` | Read-only inventory (Phase 1) |
| `manual_qa_reset.js backup` | Export business data + auth snapshot |
| `manual_qa_reset.js cleanup --dry-run` | Plan deletes (preserves admins + unknown users) |
| `manual_qa_reset.js cleanup --execute` | Wipe business data + QA auth users |
| `manual_qa_reset.js seed` | Fresh manual QA orgs/users/projects |
| `manual_qa_reset.js verify` | Auth sign-in + membership checks |

Backups land in `backups/manual_qa_reset_<timestamp>/` (gitignored).

See [docs/qa/MANUAL_QA_USERS.md](../../docs/qa/MANUAL_QA_USERS.md) for credentials and flows.
