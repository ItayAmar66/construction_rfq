#!/usr/bin/env node
/**
 * Assign platformAdmin custom claim via Firebase Admin SDK.
 *
 * Project: construction-rfq-itay-20-2eee0
 *
 * Prerequisites:
 *   1. Service account JSON with Firebase Auth admin, OR Application Default Credentials.
 *   2. npm install in tools/admin
 *
 * Usage:
 *   cd tools/admin
 *   npm install
 *   export GOOGLE_APPLICATION_CREDENTIALS="/path/to/serviceAccount.json"
 *   node set_platform_admin.js itayamar206@gmail.com
 *
 * Or with gcloud ADC:
 *   gcloud auth application-default login
 *   node set_platform_admin.js itayamar206@gmail.com
 *
 * User must sign out and sign in again for the claim to apply in the app.
 */

const admin = require('firebase-admin');

const PROJECT_ID = 'construction-rfq-itay-20-2eee0';
const DEFAULT_EMAIL = 'itayamar206@gmail.com';

async function main() {
  const email = (process.argv[2] || DEFAULT_EMAIL).trim().toLowerCase();
  if (!email.includes('@')) {
    console.error('Usage: node set_platform_admin.js <email>');
    process.exit(1);
  }

  if (!admin.apps.length) {
    admin.initializeApp({ projectId: PROJECT_ID });
  }

  const user = await admin.auth().getUserByEmail(email);
  const existing = user.customClaims || {};
  await admin.auth().setCustomUserClaims(user.uid, {
    ...existing,
    platformAdmin: true,
  });

  console.log(`platformAdmin=true set for ${email}`);
  console.log(`uid: ${user.uid}`);
  console.log('Ask the user to sign out and sign in again.');
}

main().catch((err) => {
  console.error(err.message || err);
  process.exit(1);
});
