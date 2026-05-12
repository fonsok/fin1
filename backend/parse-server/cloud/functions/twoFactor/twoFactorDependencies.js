'use strict';

let otplibModule;
let toDataURL;

try {
  otplibModule = require('otplib');
  console.log('otplib loaded successfully');
} catch (e) {
  console.warn('otplib not installed - 2FA functions will not work');
}

try {
  const qrcode = require('qrcode');
  toDataURL = qrcode.toDataURL;
  console.log('qrcode loaded successfully');
} catch (e) {
  console.warn('qrcode not installed - QR code generation will not work');
}

module.exports = {
  get otplibModule() {
    return otplibModule;
  },
  get toDataURL() {
    return toDataURL;
  },
};
