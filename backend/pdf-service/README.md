# FIN1 PDF Generation Service

Professional PDF generation for financial documents using Python and WeasyPrint.

## Features

- **DIN A4 Format**: All documents are generated in standard A4 size (210mm × 297mm)
- **DIN 5008 Compliant**: Follows German business letter standards
- **GoB Compliant**: Adheres to principles of proper accounting (Grundsätze ordnungsgemäßer Buchführung)
- **Professional Design**: Clean, modern typography and layout
- **QR Codes**: Automatic QR code generation for document verification

## Document Types

| Document | Endpoint | Description |
|----------|----------|-------------|
| **Invoice** | `POST /api/pdf/invoice` | Wertpapierabrechnung, Rechnung |
| **Trade Statement** | `POST /api/pdf/trade-statement` | Sammelabrechnung |
| **Credit Note** | `POST /api/pdf/credit-note` | Gutschrift |
| **Account Statement** | `POST /api/pdf/account-statement` | Kontoauszug |

## Technology Stack

- **Python 3.11** - Runtime
- **FastAPI** - Web framework
- **WeasyPrint** - HTML/CSS to PDF conversion
- **Jinja2** - HTML templating
- **QRCode** - QR code generation

## Quick Start

### Local Development

```bash
# Install dependencies
pip install -r requirements.txt

# Run the service
python main.py

# Or with uvicorn
uvicorn main:app --reload --port 8083
```

### Docker

```bash
# Build and run with Docker Compose (from project root)
docker-compose up -d pdf-service

# Or build individually
cd backend/pdf-service
docker build -t fin1-pdf-service .
docker run -p 8083:8083 fin1-pdf-service
```

## API Usage

### Generate Invoice PDF

```bash
curl -X POST http://localhost:8083/api/pdf/invoice \
  -H "Content-Type: application/json" \
  -d '{
    "invoice_number": "R-2026-001",
    "invoice_type": "securitiesSettlement",
    "customer_info": {
      "name": "Max Mustermann",
      "address": "Beispielstraße 42",
      "city": "Berlin",
      "postal_code": "12345",
      "customer_number": "K-12345",
      "depot_number": "D-54321"
    },
    "items": [
      {
        "description": "Apple Inc. (AAPL)",
        "quantity": 100,
        "unit_price": 150.00,
        "total_amount": 15000.00,
        "item_type": "securities"
      },
      {
        "description": "Ordergebühr",
        "quantity": 1,
        "unit_price": 15.00,
        "total_amount": 15.00,
        "item_type": "orderFee"
      }
    ],
    "subtotal": 15015.00,
    "total_tax": 0.00,
    "total_amount": 15015.00
  }' \
  --output rechnung.pdf
```

### Generate Trade Statement PDF

```bash
curl -X POST http://localhost:8083/api/pdf/trade-statement \
  -H "Content-Type: application/json" \
  -d '{
    "trade_number": 1,
    "depot_number": "D-54321",
    "depot_holder": "Max Mustermann",
    "security_identifier": "Apple Inc. (AAPL)",
    "account_number": "K-12345",
    "buy_transaction": {
      "transactionNumber": "T-001",
      "orderVolume": "100 Stück",
      "executedVolume": "100 Stück",
      "price": "150,00 €",
      "marketValue": "15.000,00 €",
      "commission": "15,00 €",
      "ownExpenses": "0,00 €",
      "externalExpenses": "5,00 €",
      "finalAmount": "15.020,00 €"
    },
    "sell_transactions": [],
    "calculation_breakdown": {
      "totalSellAmount": "0,00 €",
      "buyAmount": "15.020,00 €",
      "resultBeforeTaxes": "-15.020,00 €"
    },
    "tax_summary": {
      "assessmentBasis": "0,00 €",
      "totalTax": "0,00 €",
      "netResult": "-15.020,00 €"
    },
    "legal_disclaimer": "Diese Abrechnung wurde maschinell erstellt."
  }' \
  --output sammelabrechnung.pdf
```

## Health Check

```bash
curl http://localhost:8083/health
```

## Templates

Templates are located in `/templates/`:

- `invoice.html` - Invoice/Wertpapierabrechnung template
- `trade_statement.html` - Sammelabrechnung template
- `credit_note.html` - Gutschrift template
- `account_statement.html` - Kontoauszug template
- `styles.css` - Shared styles (DIN 5008 compliant)

## Document Layout (DIN 5008)

```
┌────────────────────────────────────────────────────────────┐
│  [Company Logo]                              [QR Code]     │
│  FIN1 Trading GmbH                                         │
│  Musterstraße 1 | 12345 Berlin                             │
├────────────────────────────────────────────────────────────┤
│  ← Return Address Line →                                   │
│  ┌──────────────────────┐    ┌────────────────────────┐    │
│  │  RECIPIENT           │    │  Invoice Number        │    │
│  │  Max Mustermann      │    │  Date                  │    │
│  │  Street Address      │    │  Customer Number       │    │
│  │  City, ZIP           │    │  Depot Number          │    │
│  └──────────────────────┘    └────────────────────────┘    │
│                                                            │
│  DOCUMENT TITLE (e.g., Wertpapierabrechnung)               │
├────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────┐   │
│  │ Position │ Quantity │ Price    │ Amount   │ Type   │   │
│  ├──────────┼──────────┼──────────┼──────────┼────────┤   │
│  │ Item 1   │     100  │ €150.00  │€15,000   │ Wertpa │   │
│  │ Item 2   │       1  │  €15.00  │    €15   │ Gebühr │   │
│  └─────────────────────────────────────────────────────┘   │
│                              ┌──────────────────────────┐  │
│                              │ Subtotal:    €15,015.00  │  │
│                              │ Tax:              €0.00  │  │
│                              │ TOTAL:       €15,015.00  │  │
│                              └──────────────────────────┘  │
├────────────────────────────────────────────────────────────┤
│  Notes and disclaimers...                                  │
│  ─────────────────────────────────────────────────────     │
│  FIN1 Trading GmbH | HRB 123456 | USt-IdNr.: DE123456789   │
│  Geschäftsführung: Max Mustermann                          │
└────────────────────────────────────────────────────────────┘
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PARSE_SERVER_URL` | `http://parse-server:1337/parse` | Parse Server URL |
| `PARSE_SERVER_APPLICATION_ID` | `fin1-app-id` | Parse App ID |
| `PARSE_SERVER_MASTER_KEY` | `fin1-master-key` | Parse Master Key |
| `MINIO_ENDPOINT` | `minio:9000` | MinIO endpoint |
| `MINIO_ACCESS_KEY` | `fin1-minio-admin` | MinIO access key |
| `MINIO_SECRET_KEY` | `fin1-minio-password` | MinIO secret key |
| `MINIO_BUCKET` | `fin1-documents` | MinIO bucket name |

## iOS Integration

The iOS app can use `PDFBackendService` to generate PDFs:

```swift
// Configure PDF generation mode
PDFGenerator.generationMode = .backend

// Generate PDF asynchronously
let pdfData = try await PDFGenerator.generatePDFAsync(from: invoice)

// Or use the service directly
let service = PDFBackendService()
let pdfData = try await service.generateInvoicePDF(from: invoice)
```

## License

Copyright © 2026 FIN1. All rights reserved.
