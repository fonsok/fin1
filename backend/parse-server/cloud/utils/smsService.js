// ============================================================================
// SMS Service for FIN1
// utils/smsService.js
// ============================================================================
//
// Brevo Transactional SMS API (https://developers.brevo.com/reference/sendtransacsms)
//
// Environment variables:
//   BREVO_API_KEY   - Brevo API key (xkeysib-...)
//   SMS_SENDER      - Sender name (max 11 chars, alphanumeric). Default: "FIN1"
//
// ============================================================================

'use strict';

const https = require('https');

const BREVO_SMS_URL = 'https://api.brevo.com/v3/transactionalSMS/sms';

/**
 * Send an SMS via Brevo transactional SMS API.
 * @param {Object} opts
 * @param {string} opts.to  - E.164 phone number (e.g. +491771234567)
 * @param {string} opts.text - SMS body (max ~160 chars recommended)
 * @returns {Promise<boolean>} true if accepted by Brevo
 */
async function sendSMS({ to, text }) {
  const apiKey = process.env.BREVO_API_KEY;
  if (!apiKey) {
    console.log(`[SMS DISABLED] Would send to ${to}: ${text}`);
    return false;
  }

  const sender = (process.env.SMS_SENDER || 'FIN1').slice(0, 11);

  const body = JSON.stringify({
    type: 'transactional',
    sender,
    recipient: to,
    content: text,
  });

  return new Promise((resolve) => {
    const url = new URL(BREVO_SMS_URL);
    const req = https.request(
      {
        hostname: url.hostname,
        path: url.pathname,
        method: 'POST',
        headers: {
          'api-key': apiKey,
          'Content-Type': 'application/json',
          'Content-Length': Buffer.byteLength(body),
        },
      },
      (res) => {
        let data = '';
        res.on('data', (chunk) => (data += chunk));
        res.on('end', () => {
          if (res.statusCode >= 200 && res.statusCode < 300) {
            console.log(`SMS sent to ${to} (status ${res.statusCode})`);
            resolve(true);
          } else {
            console.error(`SMS failed to ${to}: ${res.statusCode} ${data}`);
            resolve(false);
          }
        });
      }
    );

    req.on('error', (err) => {
      console.error(`SMS request error to ${to}:`, err.message);
      resolve(false);
    });

    req.write(body);
    req.end();
  });
}

module.exports = { sendSMS };

console.log('SMS Service loaded');
