// Apply DB-level validator for active collection bills.
// Enforces metadata.returnPercentage presence/type at Mongo boundary.

const dbName = 'fin1';
const database = db.getSiblingDB(dbName);

print('--- Applying Document validator for return% contract ---');

const command = {
  collMod: 'Document',
  validator: {
    $or: [
      // Non-collection bill documents are not constrained by this validator.
      { type: { $nin: ['investorCollectionBill', 'investor_collection_bill'] } },
      // Wallet receipt variants are excluded from this return% requirement.
      { 'metadata.receiptType': { $exists: true } },
      // Active collection bills must have numeric canonical return percentage.
      { 'metadata.returnPercentage': { $type: ['double', 'int', 'long', 'decimal'] } },
    ],
  },
  validationLevel: 'moderate',
  validationAction: 'error',
};

const result = database.runCommand(command);
printjson(result);

if (!result.ok) {
  throw new Error(`collMod failed: ${tojson(result)}`);
}

print('Validator applied successfully.');
