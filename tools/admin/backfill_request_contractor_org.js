#!/usr/bin/env node
/**
 * Backfill quoteRequests.contractorOrgId from linked project.orgId.
 * Does not delete data or touch catalog.
 *
 * Usage:
 *   cd tools/admin
 *   node backfill_request_contractor_org.js [--dry-run]
 */

const { initAdmin } = require('./lib/firebase_admin_client');

async function main() {
  const dryRun = process.argv.includes('--dry-run');
  const { db } = initAdmin();

  const requestsSnap = await db.collection('quoteRequests').get();
  let scanned = 0;
  let patched = 0;
  let skipped = 0;
  const projectCache = new Map();

  for (const doc of requestsSnap.docs) {
    scanned += 1;
    const data = doc.data();
    const existing = (data.contractorOrgId || '').trim();
    if (existing) {
      skipped += 1;
      continue;
    }
    const projectId = (data.projectId || '').trim();
    if (!projectId) {
      skipped += 1;
      continue;
    }

    let project = projectCache.get(projectId);
    if (!project) {
      const projectSnap = await db.collection('projects').doc(projectId).get();
      project = projectSnap.exists ? projectSnap.data() : null;
      projectCache.set(projectId, project);
    }
    const orgId = project?.orgId?.trim?.() || '';
    if (!orgId) {
      skipped += 1;
      continue;
    }

    patched += 1;
    if (!dryRun) {
      await doc.ref.update({ contractorOrgId: orgId });
    }
    console.log(
      `${dryRun ? '[dry-run] ' : ''}patched ${doc.id} project=${projectId} org=${orgId}`,
    );
  }

  console.log(
    JSON.stringify({ scanned, patched, skipped, dryRun }, null, 2),
  );
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
