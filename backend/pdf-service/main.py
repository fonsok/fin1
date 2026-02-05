"""
FIN1 PDF Generation Service

Professional PDF generation for invoices, trade statements, credit notes,
and account statements using WeasyPrint (HTML/CSS to PDF).

Follows German DIN 5008 business letter standards and
principles of proper accounting (GoB).
"""

import os
import io
import logging
from datetime import datetime
from typing import Optional
from pathlib import Path

from fastapi import FastAPI, HTTPException, Response
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
import httpx
from weasyprint import HTML, CSS
from jinja2 import Environment, FileSystemLoader
import qrcode
from io import BytesIO
import base64

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Configuration
PARSE_SERVER_URL = os.getenv('PARSE_SERVER_URL', 'http://parse-server:1337/parse')
PARSE_APP_ID = os.getenv('PARSE_SERVER_APPLICATION_ID', 'fin1-app-id')
PARSE_MASTER_KEY = os.getenv('PARSE_SERVER_MASTER_KEY', 'fin1-master-key')
MINIO_ENDPOINT = os.getenv('MINIO_ENDPOINT', 'minio:9000')
MINIO_ACCESS_KEY = os.getenv('MINIO_ACCESS_KEY', 'fin1-minio-admin')
MINIO_SECRET_KEY = os.getenv('MINIO_SECRET_KEY', 'fin1-minio-password')
MINIO_BUCKET = os.getenv('MINIO_BUCKET', 'fin1-documents')

# Initialize FastAPI
app = FastAPI(
    title="FIN1 PDF Service",
    description="Professional PDF generation for financial documents",
    version="1.0.0"
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Jinja2 template environment
templates_dir = Path(__file__).parent / "templates"
jinja_env = Environment(
    loader=FileSystemLoader(str(templates_dir)),
    autoescape=True
)

# === Data Models ===

class CompanyInfo(BaseModel):
    """Company information for document headers - sent from iOS app"""
    # These defaults are intentionally neutral.
    # The iOS app is expected to send `company_info` derived from LegalIdentity/Info.plist.
    name: str = 'Company Name'
    address: str = 'Street 1'
    city: str = '00000 City'
    email: str = 'support@example.com'
    phone: str = '+00 000 000000'
    website: str = 'www.example.com'
    business_hours: str = 'Mo-Fr: 9:00-18:00 Uhr'
    register_number: str = 'HRB 000000'
    vat_id: str = 'DE000000000'
    management: str = 'Geschäftsführung: —'
    bank_name: str = 'Bank'
    bank_iban: str = 'DE00 0000 0000 0000 0000 00'
    bank_bic: str = 'XXXXXXXXXXX'
    document_prefix: str = 'APP'

    class Config:
        populate_by_name = True


class CustomerInfo(BaseModel):
    """Customer information for invoices"""
    name: str
    address: str
    city: str
    postalCode: str = Field(alias='postal_code', default='')
    taxNumber: str = Field(alias='tax_number', default='')
    customerNumber: str = Field(alias='customer_number', default='')
    depotNumber: str = Field(alias='depot_number', default='')
    bank: str = ''

    class Config:
        populate_by_name = True


class InvoiceItem(BaseModel):
    """Single item in an invoice"""
    description: str
    quantity: float
    unitPrice: float = Field(alias='unit_price')
    totalAmount: float = Field(alias='total_amount')
    itemType: str = Field(alias='item_type', default='other')

    class Config:
        populate_by_name = True


class InvoiceRequest(BaseModel):
    """Request body for invoice PDF generation"""
    invoice_number: str
    invoice_type: str = 'securitiesSettlement'
    customer_info: CustomerInfo
    items: list[InvoiceItem]
    subtotal: float
    total_tax: float = 0.0
    total_amount: float
    created_at: Optional[str] = None
    trade_id: Optional[str] = None
    trade_number: Optional[int] = None
    order_id: Optional[str] = None
    transaction_type: Optional[str] = None
    tax_note: Optional[str] = None
    legal_note: Optional[str] = None
    qr_data: Optional[str] = None
    # Company info from iOS app (uses LegalIdentity)
    company_info: Optional[CompanyInfo] = None


class TradeStatementRequest(BaseModel):
    """Request body for trade statement (Collection Bill) PDF generation"""
    trade_number: int
    depot_number: str
    depot_holder: str
    security_identifier: str
    account_number: str
    buy_transaction: Optional[dict] = None
    sell_transactions: list[dict] = []
    calculation_breakdown: dict
    tax_summary: dict
    legal_disclaimer: str = ''
    # Company info from iOS app (uses LegalIdentity)
    company_info: Optional[CompanyInfo] = None


class CreditNoteRequest(BaseModel):
    """Request body for credit note PDF generation"""
    credit_note_number: str
    customer_info: CustomerInfo
    items: list[InvoiceItem]
    total_amount: float
    reason: str = ''
    original_invoice_number: Optional[str] = None
    created_at: Optional[str] = None
    qr_data: Optional[str] = None
    # Company info from iOS app (uses LegalIdentity)
    company_info: Optional[CompanyInfo] = None


class AccountStatementRequest(BaseModel):
    """Request body for monthly account statement PDF generation"""
    statement_number: str
    customer_info: CustomerInfo
    statement_period: str  # e.g., "Januar 2026"
    entries: list[dict]
    opening_balance: float
    closing_balance: float
    created_at: Optional[str] = None
    # Company info from iOS app (uses LegalIdentity)
    company_info: Optional[CompanyInfo] = None


# === Helper Functions ===

def format_currency(amount: float) -> str:
    """Format amount as German currency"""
    return f"{amount:,.2f} €".replace(",", "X").replace(".", ",").replace("X", ".")


def format_date(date_str: Optional[str] = None) -> str:
    """Format date in German format"""
    if date_str:
        try:
            dt = datetime.fromisoformat(date_str.replace('Z', '+00:00'))
            return dt.strftime('%d.%m.%Y')
        except (ValueError, AttributeError):
            pass
    return datetime.now().strftime('%d.%m.%Y')


def format_integer(value: float) -> str:
    """Format as integer with German thousand separator"""
    return f"{int(value):,}".replace(",", ".")


def generate_qr_code_base64(data: str) -> str:
    """Generate QR code as base64 data URL"""
    qr = qrcode.QRCode(
        version=1,
        error_correction=qrcode.constants.ERROR_CORRECT_M,
        box_size=4,
        border=2,
    )
    qr.add_data(data)
    qr.make(fit=True)

    img = qr.make_image(fill_color="black", back_color="white")
    buffer = BytesIO()
    img.save(buffer, format='PNG')
    buffer.seek(0)

    base64_data = base64.b64encode(buffer.getvalue()).decode('utf-8')
    return f"data:image/png;base64,{base64_data}"


def get_document_title(invoice_type: str) -> str:
    """Get German document title for invoice type"""
    titles = {
        'securitiesSettlement': 'Wertpapierabrechnung',
        'creditNote': 'Gutschrift',
        'commissionInvoice': 'Provisionsabrechnung',
        'accountStatement': 'Kontoauszug',
        'tradingFee': 'Gebührenabrechnung',
        'platformServiceCharge': 'Servicegebühr',
        'traderCollectionBill': 'Sammelabrechnung',
        'investorCollectionBill': 'Anleger-Sammelabrechnung',
    }
    return titles.get(invoice_type, 'Rechnung')


def get_item_type_name(item_type: str) -> str:
    """Get German name for invoice item type"""
    names = {
        'securities': 'Wertpapier',
        'orderFee': 'Ordergebühr',
        'exchangeFee': 'Börsengebühr',
        'foreignCosts': 'Fremdkosten',
        'serviceCharge': 'Servicegebühr',
        'vat': 'MwSt.',
        'tax': 'Steuer',
        'commission': 'Provision',
        'other': 'Sonstig',
    }
    return names.get(item_type, item_type)


def get_transaction_type_name(transaction_type: Optional[str]) -> str:
    """Get German name for transaction type"""
    if transaction_type == 'buy':
        return 'Kauf'
    elif transaction_type == 'sell':
        return 'Verkauf'
    return transaction_type or ''


# === Helper: Build Company Data ===

def build_company_data(company_info: Optional[CompanyInfo]) -> dict:
    """Build company data dict from CompanyInfo model or use defaults"""
    if company_info:
        return {
            'name': company_info.name,
            'address': company_info.address,
            'city': company_info.city,
            'email': company_info.email,
            'phone': company_info.phone,
            'website': company_info.website,
            'business_hours': company_info.business_hours,
            'contact': f'{company_info.email} | {company_info.phone}',
            'legal': f'Amtsgericht Frankfurt | {company_info.register_number} | USt-IdNr.: {company_info.vat_id}',
            'management': company_info.management,
            'bank': f'{company_info.bank_name} | IBAN: {company_info.bank_iban} | BIC: {company_info.bank_bic}',
        }
    # Default fallback (neutral placeholders)
    return {
        'name': 'Company Name',
        'address': 'Street 1',
        'city': '00000 City',
        'email': 'support@example.com',
        'phone': '+00 000 000000',
        'website': 'www.example.com',
        'business_hours': 'Mo-Fr: 9:00-18:00 Uhr',
        'contact': 'support@example.com | +00 000 000000',
        'legal': 'Amtsgericht — | HRB 000000 | USt-IdNr.: DE000000000',
        'management': 'Geschäftsführung: —',
        'bank': 'Bank | IBAN: DE00 0000 0000 0000 0000 00 | BIC: XXXXXXXXXXX',
    }


# === PDF Generation ===

def generate_invoice_pdf(request: InvoiceRequest) -> bytes:
    """Generate professional invoice PDF"""
    logger.info(f"Generating invoice PDF: {request.invoice_number}")

    # Prepare template data
    template_data = {
        'company': build_company_data(request.company_info),
        'document': {
            'title': get_document_title(request.invoice_type),
            'number': request.invoice_number,
            'date': format_date(request.created_at),
            'trade_number': f"{request.trade_number:03d}" if request.trade_number else None,
            'trade_id': request.trade_id,
            'order_id': request.order_id,
            'transaction_type': get_transaction_type_name(request.transaction_type),
        },
        'customer': {
            'name': request.customer_info.name,
            'address': request.customer_info.address,
            'city': f"{request.customer_info.postalCode} {request.customer_info.city}",
            'tax_number': request.customer_info.taxNumber,
            'customer_number': request.customer_info.customerNumber,
            'depot_number': request.customer_info.depotNumber,
            'bank': request.customer_info.bank,
        },
        'items': [
            {
                'description': item.description,
                'quantity': format_integer(item.quantity),
                'unit_price': format_currency(item.unitPrice),
                'total': format_currency(item.totalAmount),
                'type': get_item_type_name(item.itemType),
            }
            for item in request.items
        ],
        'totals': {
            'subtotal': format_currency(request.subtotal),
            'tax': format_currency(request.total_tax) if request.total_tax > 0 else None,
            'total': format_currency(request.total_amount),
        },
        'notes': {
            'tax': request.tax_note,
            'legal': request.legal_note,
        },
        'qr_code': generate_qr_code_base64(request.qr_data) if request.qr_data else None,
        'format_currency': format_currency,
        'format_date': format_date,
    }

    # Render HTML template
    template = jinja_env.get_template('invoice.html')
    html_content = template.render(**template_data)

    # Generate PDF
    html = HTML(string=html_content, base_url=str(templates_dir))
    css = CSS(filename=str(templates_dir / 'styles.css'))

    pdf_bytes = html.write_pdf(stylesheets=[css])

    logger.info(f"Invoice PDF generated: {len(pdf_bytes)} bytes")
    return pdf_bytes


def generate_trade_statement_pdf(request: TradeStatementRequest) -> bytes:
    """Generate professional trade statement (Collection Bill) PDF"""
    logger.info(f"Generating trade statement PDF: Trade #{request.trade_number:03d}")

    template_data = {
        'company': build_company_data(request.company_info),
        'document': {
            'title': 'Sammelabrechnung',
            'trade_number': f"{request.trade_number:03d}",
            'date': format_date(),
        },
        'depot': {
            'number': request.depot_number,
            'holder': request.depot_holder,
            'security': request.security_identifier,
            'account': request.account_number,
        },
        'buy_transaction': request.buy_transaction,
        'sell_transactions': request.sell_transactions,
        'calculation': request.calculation_breakdown,
        'tax_summary': request.tax_summary,
        'legal_disclaimer': request.legal_disclaimer,
        'format_currency': format_currency,
        'format_date': format_date,
    }

    template = jinja_env.get_template('trade_statement.html')
    html_content = template.render(**template_data)

    html = HTML(string=html_content, base_url=str(templates_dir))
    css = CSS(filename=str(templates_dir / 'styles.css'))

    pdf_bytes = html.write_pdf(stylesheets=[css])

    logger.info(f"Trade statement PDF generated: {len(pdf_bytes)} bytes")
    return pdf_bytes


def generate_credit_note_pdf(request: CreditNoteRequest) -> bytes:
    """Generate professional credit note PDF"""
    logger.info(f"Generating credit note PDF: {request.credit_note_number}")

    template_data = {
        'company': build_company_data(request.company_info),
        'document': {
            'title': 'Gutschrift',
            'number': request.credit_note_number,
            'date': format_date(request.created_at),
            'original_invoice': request.original_invoice_number,
            'reason': request.reason,
        },
        'customer': {
            'name': request.customer_info.name,
            'address': request.customer_info.address,
            'city': f"{request.customer_info.postalCode} {request.customer_info.city}",
            'customer_number': request.customer_info.customerNumber,
            'depot_number': request.customer_info.depotNumber,
        },
        'items': [
            {
                'description': item.description,
                'quantity': format_integer(item.quantity),
                'unit_price': format_currency(item.unitPrice),
                'total': format_currency(item.totalAmount),
                'type': get_item_type_name(item.itemType),
            }
            for item in request.items
        ],
        'totals': {
            'total': format_currency(request.total_amount),
        },
        'qr_code': generate_qr_code_base64(request.qr_data) if request.qr_data else None,
        'format_currency': format_currency,
    }

    template = jinja_env.get_template('credit_note.html')
    html_content = template.render(**template_data)

    html = HTML(string=html_content, base_url=str(templates_dir))
    css = CSS(filename=str(templates_dir / 'styles.css'))

    pdf_bytes = html.write_pdf(stylesheets=[css])

    logger.info(f"Credit note PDF generated: {len(pdf_bytes)} bytes")
    return pdf_bytes


def generate_account_statement_pdf(request: AccountStatementRequest) -> bytes:
    """Generate professional monthly account statement PDF"""
    logger.info(f"Generating account statement PDF: {request.statement_number}")

    template_data = {
        'company': build_company_data(request.company_info),
        'document': {
            'title': 'Kontoauszug',
            'number': request.statement_number,
            'period': request.statement_period,
            'date': format_date(request.created_at),
        },
        'customer': {
            'name': request.customer_info.name,
            'address': request.customer_info.address,
            'city': f"{request.customer_info.postalCode} {request.customer_info.city}",
            'customer_number': request.customer_info.customerNumber,
            'depot_number': request.customer_info.depotNumber,
        },
        'entries': request.entries,
        'balances': {
            'opening': format_currency(request.opening_balance),
            'closing': format_currency(request.closing_balance),
        },
        'format_currency': format_currency,
        'format_date': format_date,
    }

    template = jinja_env.get_template('account_statement.html')
    html_content = template.render(**template_data)

    html = HTML(string=html_content, base_url=str(templates_dir))
    css = CSS(filename=str(templates_dir / 'styles.css'))

    pdf_bytes = html.write_pdf(stylesheets=[css])

    logger.info(f"Account statement PDF generated: {len(pdf_bytes)} bytes")
    return pdf_bytes


# === API Endpoints ===

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "service": "pdf-service",
        "timestamp": datetime.now().isoformat(),
    }


@app.post("/api/pdf/invoice")
async def create_invoice_pdf(request: InvoiceRequest):
    """Generate invoice PDF and return it"""
    try:
        pdf_bytes = generate_invoice_pdf(request)
        return Response(
            content=pdf_bytes,
            media_type="application/pdf",
            headers={
                "Content-Disposition": f'attachment; filename="rechnung_{request.invoice_number}.pdf"'
            }
        )
    except Exception as e:
        logger.error(f"Error generating invoice PDF: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/api/pdf/trade-statement")
async def create_trade_statement_pdf(request: TradeStatementRequest):
    """Generate trade statement (Collection Bill) PDF and return it"""
    try:
        pdf_bytes = generate_trade_statement_pdf(request)
        return Response(
            content=pdf_bytes,
            media_type="application/pdf",
            headers={
                "Content-Disposition": f'attachment; filename="sammelabrechnung_trade_{request.trade_number:03d}.pdf"'
            }
        )
    except Exception as e:
        logger.error(f"Error generating trade statement PDF: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/api/pdf/credit-note")
async def create_credit_note_pdf(request: CreditNoteRequest):
    """Generate credit note PDF and return it"""
    try:
        pdf_bytes = generate_credit_note_pdf(request)
        return Response(
            content=pdf_bytes,
            media_type="application/pdf",
            headers={
                "Content-Disposition": f'attachment; filename="gutschrift_{request.credit_note_number}.pdf"'
            }
        )
    except Exception as e:
        logger.error(f"Error generating credit note PDF: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/api/pdf/account-statement")
async def create_account_statement_pdf(request: AccountStatementRequest):
    """Generate monthly account statement PDF and return it"""
    try:
        pdf_bytes = generate_account_statement_pdf(request)
        return Response(
            content=pdf_bytes,
            media_type="application/pdf",
            headers={
                "Content-Disposition": f'attachment; filename="kontoauszug_{request.statement_number}.pdf"'
            }
        )
    except Exception as e:
        logger.error(f"Error generating account statement PDF: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/api/pdf/templates")
async def list_templates():
    """List available PDF templates"""
    return {
        "templates": [
            {"id": "invoice", "name": "Rechnung/Wertpapierabrechnung", "endpoint": "/api/pdf/invoice"},
            {"id": "trade-statement", "name": "Sammelabrechnung", "endpoint": "/api/pdf/trade-statement"},
            {"id": "credit-note", "name": "Gutschrift", "endpoint": "/api/pdf/credit-note"},
            {"id": "account-statement", "name": "Kontoauszug", "endpoint": "/api/pdf/account-statement"},
        ]
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8083)
