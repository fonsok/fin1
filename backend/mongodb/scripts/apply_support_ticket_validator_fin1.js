// ============================================================================
// mongosh — SupportTicket validator (collMod) für bestehende DB
// ============================================================================
// Entspricht dem Block in init/02_schema_validation.js. validationLevel/Action
// wie im Repo: moderate + warn.
//
//   docker compose exec -T mongodb mongosh -u admin -p … --authenticationDatabase admin fin1 --file …
// ============================================================================

db = db.getSiblingDB('fin1');

print('Applying collMod SupportTicket validator (userId, warn)...');

const res = db.runCommand({
  collMod: 'SupportTicket',
  validator: {
    $jsonSchema: {
      bsonType: 'object',
      required: ['ticketNumber', 'userId', 'subject', 'description', 'category', 'priority', 'status'],
      properties: {
        ticketNumber: {
          bsonType: 'string',
          pattern: '^TKT-[0-9]{4}-[0-9]{5}$',
          description: 'Ticket number must match pattern',
        },
        userId: {
          bsonType: 'string',
          description: 'Parse _User.objectId of the end customer',
        },
        category: {
          enum: [
            'general', 'account_issue', 'technical_issue', 'billing',
            'investment', 'trading_question', 'security', 'feedback',
            'complaint', 'kyc', 'fraud_report',
          ],
          description: 'Category must be valid',
        },
        priority: {
          enum: ['low', 'medium', 'high', 'urgent'],
          description: 'Priority must be valid',
        },
        status: {
          enum: [
            'open', 'in_progress', 'waiting_for_customer',
            'escalated', 'resolved', 'closed', 'archived',
          ],
          description: 'Status must be valid',
        },
      },
    },
  },
  validationLevel: 'moderate',
  validationAction: 'warn',
});

printjson(res);
