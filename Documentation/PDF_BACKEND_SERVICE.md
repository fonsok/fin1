# PDF Backend Service

Professionelle PDF-Generierung für Finanzdokumente über Backend (Ubuntu Server).

## Übersicht

Der PDF-Service generiert DIN A4 konforme Dokumente nach deutschen Geschäftsbrief-Standards (DIN 5008) und den Grundsätzen ordnungsgemäßer Buchführung (GoB).

## Architektur

```
┌─────────────────────┐        ┌─────────────────────┐
│     iOS App         │        │   Ubuntu Server     │
│                     │        │   (fin1-server)     │
│  PDFBackendService  │──HTTP──▶  pdf-service:8083   │
│                     │        │                     │
│  LegalIdentity      │        │  WeasyPrint         │
│  CompanyContactInfo │        │  HTML Templates     │
└─────────────────────┘        └─────────────────────┘
```

## Dokumenttypen

| Typ | Endpoint | Beschreibung |
|-----|----------|--------------|
| Rechnung | `POST /api/pdf/invoice` | Wertpapierabrechnung |
| Sammelabrechnung | `POST /api/pdf/trade-statement` | Collection Bill |
| Gutschrift | `POST /api/pdf/credit-note` | Credit Note |
| Kontoauszug | `POST /api/pdf/account-statement` | Monthly Statement |

## Dateien

### Backend (Python)

| Datei | Beschreibung |
|-------|--------------|
| `backend/pdf-service/main.py` | FastAPI Server |
| `backend/pdf-service/requirements.txt` | Python-Abhängigkeiten |
| `backend/pdf-service/Dockerfile` | Docker-Container |
| `backend/pdf-service/templates/` | HTML/CSS Templates |

### iOS (Swift)

| Datei | Beschreibung |
|-------|--------------|
| `FIN1/Shared/Services/PDFBackendService.swift` | HTTP Client |
| `FIN1/Features/Trader/Utils/PDFGenerator.swift` | Facade (lokal/backend) |

## Firmendaten-Flow

Die iOS-App sendet die Firmendaten aus `LegalIdentity` und `CompanyContactInfo` an das Backend:

```swift
// iOS: CompanyInfoDTO.fromLegalIdentity()
{
  "name": "TTTT Investing GmbH",         // LegalIdentity.companyLegalName
  "address": "Hauptstraße 100",          // LegalIdentity.companyAddressLine
  "email": "info@tttt-investing.com",     // CompanyContactInfo.email (default derived from Display Name)
  "phone": "+49 (0) 69 12345678",        // CompanyContactInfo.phone
  "registerNumber": "HRB 123456",        // LegalIdentity.companyRegisterNumber
  "vatId": "DE123456789",                // LegalIdentity.companyVatId
  ...
}
```

## QR Code Flow (DRY)

Die iOS-App erzeugt den QR-Payload zentral (Single Source of Truth) und sendet ihn an das Backend:

- **iOS**: `QRCodeGenerator.generateInvoiceQRData(for:)` (oder entsprechende Methode)
- **Backend**: rendert daraus nur das QR-Bild in den HTML-Templates

Request-Feld:

```json
{
  "qr_data": "{...}"
}
```

Das Backend verwendet diese Daten in den HTML-Templates:

```html
<!-- invoice.html -->
<div class="company-name">{{ company.name }}</div>
<!-- Output: "TTTT Investing GmbH" -->
```

## Verwendung

### 1. Backend starten

```bash
cd /Users/ra/app/FIN1
docker-compose up -d pdf-service
```

### 2. iOS-App konfigurieren

```swift
// In AppDelegate oder App init
PDFGenerator.generationMode = .backend
```

### 3. PDF generieren

```swift
// Asynchron (empfohlen)
let pdfData = try await PDFGenerator.generatePDFAsync(from: invoice)

// Oder direkt über den Service
let service = PDFBackendService()
let pdfData = try await service.generateInvoicePDF(from: invoice)
```

## PDF Generation Modes

| Mode | Beschreibung | Offline |
|------|--------------|---------|
| `.backend` | Backend via HTTP (empfohlen) | ❌ |
| `.professionalLocal` | Neue DIN 5008 Layout (lokal) | ✅ |
| `.local` | Legacy lokale Generierung | ✅ |

## HTML Templates

### Struktur

```
backend/pdf-service/templates/
├── styles.css              # DIN 5008 CSS
├── invoice.html            # Rechnung
├── trade_statement.html    # Sammelabrechnung
├── credit_note.html        # Gutschrift
└── account_statement.html  # Kontoauszug
```

### CSS Features

- **DIN A4 Format**: `@page { size: A4; }`
- **DIN 5008 Margins**: 25mm links, 20mm rechts
- **Seitennummerierung**: Automatisch im Footer
- **Professionelle Typografie**: Liberation Sans / DejaVu Sans
- **Tabellen**: Farbige Header, alternierende Zeilen

## API-Beispiel

```bash
curl -X POST http://fin1-server:8083/api/pdf/invoice \
  -H "Content-Type: application/json" \
  -d '{
    "invoice_number": "R-2026-001",
    "invoice_type": "securitiesSettlement",
    "customer_info": {
      "name": "Max Mustermann",
      "address": "Beispielstraße 42",
      "city": "Berlin",
      "postal_code": "12345"
    },
    "items": [...],
    "subtotal": 15015.00,
    "total_amount": 15015.00,
    "company_info": {
      "name": "TTTT Investing GmbH",
      "address": "Hauptstraße 100",
      "city": "60311 Frankfurt am Main",
      "email": "info@fin1-investing.com",
      "phone": "+49 (0) 69 12345678",
      "register_number": "HRB 123456",
      "vat_id": "DE123456789"
    }
  }' \
  --output rechnung.pdf
```

## Health Check

```bash
curl http://fin1-server:8083/health
# {"status": "healthy", "service": "pdf-service", ...}
```

## Troubleshooting

### Backend nicht erreichbar

```bash
# Container-Status prüfen
docker ps | grep pdf-service

# Logs ansehen
docker logs fin1-pdf-service

# Service neu starten
docker-compose restart pdf-service
```

### iOS Fallback

Bei Backend-Fehlern fällt die iOS-App automatisch auf lokale Generierung zurück:

```swift
catch {
    logger.error("Backend PDF failed, falling back to local")
    return PDFInvoiceGenerator.generatePDF(from: invoice)
}
```

## Technologie-Stack

- **Python 3.11**
- **FastAPI** - Web Framework
- **WeasyPrint** - HTML/CSS → PDF
- **Jinja2** - Template Engine
- **QRCode** - QR-Code Generierung
