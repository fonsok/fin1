#!/usr/bin/env python3
"""
Convert Markdown files to PDF using reportlab
Simple approach without external system dependencies
"""

import sys
import os
import re
from pathlib import Path

def install_packages():
    """Install required packages if not available"""
    try:
        import markdown
        from reportlab.lib.pagesizes import A4
        from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
        from reportlab.lib.units import cm
        from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, PageBreak, Preformatted
        from reportlab.lib import colors
        from reportlab.pdfbase import pdfmetrics
        from reportlab.pdfbase.ttfonts import TTFont
        return True
    except ImportError:
        print("Required packages not found. Installing markdown and reportlab...")
        import subprocess
        try:
            # Try user installation first (works in most cases)
            subprocess.check_call([
                sys.executable, "-m", "pip", "install",
                "--user", "--quiet", "markdown", "reportlab"
            ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            print("✓ Packages installed successfully")
            return True
        except subprocess.CalledProcessError:
            print("Warning: Could not install packages automatically.")
            print("Please install manually: pip3 install --user markdown reportlab")
            print("Or use a virtual environment.")
            sys.exit(1)

def replace_emojis_with_text(text):
    """Replace emojis with text equivalents to avoid rendering issues in PDF"""
    # Common emojis and symbols used in the documents
    # Remove all square/box characters that might render as black squares
    replacements = {
        '✅': '',  # Remove checkmark emoji
        '⚠️': '',  # Remove warning emoji
        '❌': '',  # Remove X emoji
        '■': '',   # Remove black square (U+25A0)
        '□': '',   # Remove white square (U+25A1)
        '▪': '',   # Remove black small square (U+25AA)
        '▫': '',   # Remove white small square (U+25AB)
        '⬛': '',  # Remove black large square (U+2B1B)
        '⬜': '',  # Remove white large square (U+2B1C)
        '🔒': '',  # Remove lock emoji
        '⭐': '',  # Remove star emoji
        # Keep normal bullet points (• and ·) - they render fine
    }

    for emoji, replacement in replacements.items():
        text = text.replace(emoji, replacement)

    return text

def localize_currency(text, is_german=False):
    """Localize currency formats based on language - process in correct order"""
    # Convert K/M/B to full numbers for formatting
    multipliers = {'K': 1000, 'M': 1000000, 'B': 1000000000}

    def format_single_amount(amount_str, suffix):
        """Format a single amount like '50K' or '2M'"""
        try:
            num = float(amount_str)
            if suffix in multipliers:
                num *= multipliers[suffix]
            num = int(num)

            if is_german:
                # German: 50.000 € (point separator, space before €)
                formatted = f"{num:,}".replace(',', '.')
                return f"{formatted} €"
            else:
                # English: €50,000 (comma separator, € before)
                formatted = f"{num:,}"
                return f"€{formatted}"
        except:
            return f"€{amount_str}{suffix}"

    def add_spaces_around_symbols(text):
        """Add spaces around currency symbols, hyphens, and plus signs for better readability"""
        # Add space before € if number is directly before it (e.g., "50.000€" -> "50.000 €")
        # But avoid if there's already a space
        text = re.sub(r'(\d[.,\d]+)(?<!\s)(€)', r'\1 \2', text)

        # Add space after € if number follows without space (e.g., "€50" -> "€ 50")
        # But only if it's not already part of a formatted amount
        text = re.sub(r'(€)(?<!\s)(\d)', r'\1 \2', text)

        # Ensure space around hyphens in ranges (e.g., "50.000€-150.000€" -> "50.000 € - 150.000 €")
        # Handle cases with € symbol
        text = re.sub(r'(\d[.,\d]*\s*€)\s*-\s*(\d[.,\d]*\s*€)', r'\1 - \2', text)
        # Handle number ranges without €
        text = re.sub(r'(\d[.,\d]+)\s*-\s*(\d[.,\d]+)', r'\1 - \2', text)

        # Add space before + if directly after number or € (e.g., "50.000€+" -> "50.000 € +")
        text = re.sub(r'(\d[.,\d]+\s*€)\s*\+', r'\1 +', text)
        text = re.sub(r'(\d[.,\d]+)\s*\+', r'\1 +', text)

        # Clean up multiple consecutive spaces (but preserve single spaces)
        text = re.sub(r' {2,}', ' ', text)

        return text

    # IMPORTANT: Process in order from most specific to least specific
    # Pattern 1: Ranges like €50K-150K, €5K-15K (MUST be first to avoid partial matches)
    def replace_range(match):
        amount1 = match.group(1)
        suffix1 = match.group(2) or ''
        amount2 = match.group(3)
        suffix2 = match.group(4) or ''
        formatted1 = format_single_amount(amount1, suffix1)
        formatted2 = format_single_amount(amount2, suffix2)
        if is_german:
            return f"{formatted1} - {formatted2}"  # Space around hyphen
        else:
            return f"{formatted1} - {formatted2}"  # Space around hyphen

    # Match ranges: €50K-150K or €50K-€150K
    text = re.sub(r'€(\d+(?:\.\d+)?)([KMB]?)-€?(\d+(?:\.\d+)?)([KMB]?)', replace_range, text)

    # Also fix cases where first part was already converted: "50.000 €-150K"
    def fix_partial_range(match):
        prefix = match.group(1)  # Already formatted part like "50.000 €"
        amount2 = match.group(2)
        suffix2 = match.group(3) or ''
        formatted2 = format_single_amount(amount2, suffix2)
        # Remove € from formatted2 if prefix already has it
        if '€' in prefix:
            formatted2_clean = formatted2.replace(' €', '').replace('€', '').strip()
            if is_german:
                return f"{prefix} - {formatted2_clean} €"  # Space around hyphen
            else:
                return f"{prefix} - €{formatted2_clean}"  # Space around hyphen
        return f"{prefix} - {formatted2}"  # Space around hyphen

    text = re.sub(r'([\d.,]+\s*€)-(\d+)([KMB]?)(?=\s|$|[^\d])', fix_partial_range, text)

    # Pattern 2: With plus like €2M+ (before simple amounts)
    def replace_plus(match):
        amount = match.group(1)
        suffix = match.group(2) or ''
        formatted = format_single_amount(amount, suffix)
        return f"{formatted} +"  # Space before plus

    text = re.sub(r'€(\d+(?:\.\d+)?)([KMB]?)\+', replace_plus, text)

    # Pattern 3: Simple amounts like €50K, €2M, €500K (LAST to catch remaining)
    def replace_simple(match):
        amount = match.group(1)
        suffix = match.group(2) or ''
        return format_single_amount(amount, suffix)

    text = re.sub(r'€(\d+(?:\.\d+)?)([KMB]?)', replace_simple, text)

    # Clean up any remaining K/M/B suffixes that weren't caught (standalone, after €)
    # This catches cases like "50.000 €150K" where the second amount wasn't processed
    def fix_remaining_suffix(match):
        prefix = match.group(1)  # Text before (e.g., "50.000 €")
        amount = match.group(2)
        suffix = match.group(3)
        formatted = format_single_amount(amount, suffix)
        # Remove the € from formatted if it's already in prefix
        if '€' in prefix and '€' in formatted:
            formatted = formatted.replace('€', '').strip()
        return f"{prefix} - {formatted}"  # Space around hyphen

    # Fix patterns like "50.000 €150K" -> "50.000 € - 150.000 €"
    text = re.sub(r'([\d.,]+\s*€)(\d+)([KMB])(?=\s|$|[^\d])', fix_remaining_suffix, text)

    # Also fix standalone K/M/B after numbers (not after €)
    text = re.sub(r'(\d+)([KMB])(?=\s|$|[^\d,\.])', lambda m: format_single_amount(m.group(1), m.group(2)), text)

    # Final cleanup: Add spaces around symbols for better readability
    text = add_spaces_around_symbols(text)

    return text

def calculate_column_widths(table_data, available_width, styles):
    """Calculate optimal column widths based on content length"""
    from reportlab.platypus import Paragraph
    from reportlab.lib.units import cm

    if not table_data or not table_data[0]:
        return []

    num_cols = len(table_data[0])
    if num_cols == 0:
        return []

    # Estimate character width (approximate: 1 character ≈ 0.5 points at 9pt font)
    # We'll use a more accurate method: measure actual text width
    col_max_lengths = [0] * num_cols

                # Find maximum content length for each column
    # Detect if German based on content (check for common German words)
    is_german_content = any('€' in str(cell) and any(word in str(cell).lower() for word in ['monatlich', 'jährlich', 'einrichtung']) for row in table_data for cell in row)

    for row in table_data:
        for col_idx, cell in enumerate(row):
            if col_idx < num_cols:
                # Remove markdown formatting to get plain text length
                plain_text = cell
                # Replace emojis first
                plain_text = replace_emojis_with_text(plain_text)
                # Localize currency for width calculation (to get accurate length)
                plain_text = localize_currency(plain_text, is_german_content)
                plain_text = re.sub(r'\*\*(.+?)\*\*', r'\1', plain_text)  # Remove bold
                plain_text = re.sub(r'\*(.+?)\*', r'\1', plain_text)  # Remove italic
                plain_text = re.sub(r'`(.+?)`', r'\1', plain_text)  # Remove code
                plain_text = re.sub(r'<br\s*/?>', ' ', plain_text)  # Replace <br> with space
                plain_text = re.sub(r'<[^>]+>', '', plain_text)  # Remove HTML tags

                # Estimate width: use character count with weight
                # Longer text gets more weight, but we also consider word count
                char_count = len(plain_text)
                word_count = len(plain_text.split())

                # Weighted length: characters + words (words are more important for layout)
                weighted_length = char_count * 0.5 + word_count * 3

                col_max_lengths[col_idx] = max(col_max_lengths[col_idx], weighted_length)

    # Calculate proportional widths
    total_weight = sum(col_max_lengths)
    if total_weight == 0:
        # Fallback: equal widths
        col_width = available_width / num_cols
        return [col_width] * num_cols

    # Minimum column width (to prevent too narrow columns)
    # Increased minimum for better readability, especially for first column
    min_col_width = available_width * 0.12  # At least 12% of available width
    max_col_width = available_width * 0.45   # At most 45% of available width

    # Special handling for first column (often contains labels)
    # Ensure it has enough space for typical label lengths
    if num_cols > 0 and col_max_lengths[0] > 0:
        min_col_width = max(min_col_width, available_width * 0.15)  # First column gets at least 15%

    col_widths = []
    for weight in col_max_lengths:
        if weight > 0:
            width = (weight / total_weight) * available_width
            width = max(min_col_width, min(width, max_col_width))
        else:
            width = min_col_width
        col_widths.append(width)

    # Normalize to ensure total width equals available_width
    total_allocated = sum(col_widths)
    if total_allocated > 0:
        scale_factor = available_width / total_allocated
        col_widths = [w * scale_factor for w in col_widths]
    else:
        # Fallback: equal widths
        col_width = available_width / num_cols
        col_widths = [col_width] * num_cols

    return col_widths

def markdown_to_paragraphs(md_content, styles, available_width, is_german=False):
    """Convert markdown content to reportlab paragraphs"""
    from reportlab.platypus import Paragraph, Spacer, Table, TableStyle, Preformatted
    from reportlab.lib import colors
    from reportlab.lib.units import cm

    elements = []
    lines = md_content.split('\n')
    i = 0

    while i < len(lines):
        line = lines[i].strip()

        # Headers
        if line.startswith('# '):
            header_text = replace_emojis_with_text(line[2:])
            elements.append(Spacer(1, 0.5*cm))
            elements.append(Paragraph(header_text, styles['Heading1']))
            elements.append(Spacer(1, 0.3*cm))
        elif line.startswith('## '):
            header_text = replace_emojis_with_text(line[3:])
            elements.append(Spacer(1, 0.4*cm))
            elements.append(Paragraph(header_text, styles['Heading2']))
            elements.append(Spacer(1, 0.2*cm))
        elif line.startswith('### '):
            header_text = replace_emojis_with_text(line[4:])
            elements.append(Spacer(1, 0.3*cm))
            elements.append(Paragraph(header_text, styles['Heading3']))
            elements.append(Spacer(1, 0.15*cm))
        # Horizontal rule
        elif line.startswith('---'):
            elements.append(Spacer(1, 0.3*cm))
        # Bullet lists
        elif line.startswith('- ') or line.startswith('* '):
            list_text = line[2:].strip()
            # Replace emojis in list items
            list_text = replace_emojis_with_text(list_text)
            # Localize currency
            list_text = localize_currency(list_text, is_german)
            # Convert markdown formatting
            list_text = re.sub(r'\*\*(.+?)\*\*', r'<b>\1</b>', list_text)
            list_text = re.sub(r'\*(.+?)\*', r'<i>\1</i>', list_text)
            list_text = re.sub(r'`(.+?)`', r'<font name="Courier">\1</font>', list_text)
            # Use bullet point (•) which renders correctly
            para = Paragraph('• ' + list_text, styles['Normal'])
            elements.append(para)
            elements.append(Spacer(1, 0.1*cm))
        # Code blocks
        elif line.startswith('```'):
            code_lines = []
            i += 1
            while i < len(lines) and not lines[i].strip().startswith('```'):
                code_lines.append(lines[i])
                i += 1
            if code_lines:
                code_text = '\n'.join(code_lines)
                # Use Preformatted with width constraint
                code_para = Preformatted(code_text, styles['Code'], maxLineLength=80)
                elements.append(code_para)
                elements.append(Spacer(1, 0.2*cm))
        # Tables (simple detection)
        elif '|' in line and line.count('|') >= 2:
            table_data = []
            header_line = line
            i += 1
            # Skip separator line
            if i < len(lines) and '---' in lines[i]:
                i += 1
            # Collect table rows
            while i < len(lines) and '|' in lines[i] and lines[i].count('|') >= 2:
                row = [cell.strip() for cell in lines[i].split('|')[1:-1]]
                table_data.append(row)
                i += 1
            i -= 1  # Adjust for loop increment

            if table_data:
                # Parse header
                header = [cell.strip() for cell in header_line.split('|')[1:-1]]
                table_data.insert(0, header)

                # Convert table cells to Paragraphs for text wrapping
                num_cols = len(header)
                wrapped_table_data = []
                raw_table_data = []  # Keep raw data for width calculation

                for row_idx, row in enumerate(table_data):
                    wrapped_row = []
                    raw_row = []
                    for col_idx, cell in enumerate(row):
                        raw_row.append(cell)  # Store raw cell for width calculation

                        # Convert markdown formatting in cells
                        cell_text = cell
                        # Replace emojis first (before other formatting)
                        cell_text = replace_emojis_with_text(cell_text)
                        # Localize currency
                        cell_text = localize_currency(cell_text, is_german)
                        cell_text = re.sub(r'\*\*(.+?)\*\*', r'<b>\1</b>', cell_text)
                        cell_text = re.sub(r'\*(.+?)\*', r'<i>\1</i>', cell_text)
                        cell_text = re.sub(r'`(.+?)`', r'<font name="Courier">\1</font>', cell_text)
                        cell_text = re.sub(r'<br\s*/?>', '<br/>', cell_text)  # Handle <br> tags

                        # Use appropriate style
                        if row_idx == 0:
                            para = Paragraph(cell_text, styles['Heading3'])
                        else:
                            para = Paragraph(cell_text, styles['Normal'])
                        wrapped_row.append(para)
                    wrapped_table_data.append(wrapped_row)
                    raw_table_data.append(raw_row)

                # Calculate dynamic column widths based on content
                col_widths = calculate_column_widths(raw_table_data, available_width, styles)

                # Create table with proper width constraint
                table = Table(wrapped_table_data, colWidths=col_widths, repeatRows=1)
                table.setStyle(TableStyle([
                    ('BACKGROUND', (0, 0), (-1, 0), colors.grey),
                    ('TEXTCOLOR', (0, 0), (-1, 0), colors.whitesmoke),
                    ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
                    ('VALIGN', (0, 0), (-1, -1), 'TOP'),
                    ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
                    ('FONTSIZE', (0, 0), (-1, 0), 9),
                    ('BOTTOMPADDING', (0, 0), (-1, 0), 10),
                    ('TOPPADDING', (0, 0), (-1, -1), 8),
                    ('LEFTPADDING', (0, 0), (-1, -1), 8),
                    ('RIGHTPADDING', (0, 0), (-1, -1), 8),
                    ('BACKGROUND', (0, 1), (-1, -1), colors.beige),
                    ('GRID', (0, 0), (-1, -1), 0.5, colors.black),
                    ('FONTSIZE', (0, 1), (-1, -1), 9),  # Slightly larger for better readability
                    ('ROWBACKGROUNDS', (0, 1), (-1, -1), [colors.white, colors.lightgrey]),
                    ('WORDWRAP', (0, 0), (-1, -1), True),  # Enable word wrapping
                    ('SPAN', (0, 0), (0, 0)),  # Don't span, but ensure proper cell sizing
                ]))
                elements.append(table)
                elements.append(Spacer(1, 0.3*cm))
        # Regular paragraphs
        elif line:
            # Simple markdown to HTML-like conversion for reportlab
            para_text = line
            # Replace emojis first (before other formatting)
            para_text = replace_emojis_with_text(para_text)
            # Localize currency
            para_text = localize_currency(para_text, is_german)
            # Bold
            para_text = re.sub(r'\*\*(.+?)\*\*', r'<b>\1</b>', para_text)
            # Italic
            para_text = re.sub(r'\*(.+?)\*', r'<i>\1</i>', para_text)
            # Inline code
            para_text = re.sub(r'`(.+?)`', r'<font name="Courier">\1</font>', para_text)
            # Links (simple)
            para_text = re.sub(r'\[(.+?)\]\(.+?\)', r'\1', para_text)

            # Only add paragraph if text is not empty after processing
            if para_text.strip():
                para = Paragraph(para_text, styles['Normal'])
                elements.append(para)
                elements.append(Spacer(1, 0.15*cm))

        i += 1

    return elements

def convert_md_to_pdf(md_file, pdf_file):
    """Convert Markdown file to PDF"""
    from reportlab.lib.pagesizes import A4
    from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
    from reportlab.lib.units import cm
    from reportlab.platypus import SimpleDocTemplate
    from reportlab.lib import colors

    # Detect if German version based on filename
    is_german = '_DE' in md_file.upper() or 'DE.md' in md_file.upper()

    # Read markdown file
    with open(md_file, 'r', encoding='utf-8') as f:
        md_content = f.read()

    # Calculate available width (A4 width = 21cm, minus margins)
    left_margin = 2*cm
    right_margin = 2*cm
    page_width = A4[0]  # A4 width in points
    available_width = page_width - left_margin - right_margin

    # Create PDF document with proper margins
    doc = SimpleDocTemplate(pdf_file, pagesize=A4,
                           rightMargin=right_margin,
                           leftMargin=left_margin,
                           topMargin=2*cm,
                           bottomMargin=2*cm)

    # Define styles with proper word wrapping
    styles = getSampleStyleSheet()

    # Update Normal style for better text wrapping
    styles['Normal'].wordWrap = 'CJK'  # Enable word wrapping
    styles['Normal'].fontSize = 10

    # Update heading styles
    styles['Heading1'].wordWrap = 'CJK'
    styles['Heading2'].wordWrap = 'CJK'
    styles['Heading3'].wordWrap = 'CJK'

    if 'Code' not in styles.byName:
        styles.add(ParagraphStyle(
            name='Code',
            parent=styles['Normal'],
            fontName='Courier',
            fontSize=8,
            leftIndent=0.5*cm,
            rightIndent=0.5*cm,
            backColor=colors.lightgrey,
            borderPadding=5,
            wordWrap='CJK',
        ))

    # Convert markdown to PDF elements with available width
    elements = markdown_to_paragraphs(md_content, styles, available_width, is_german)

    # Build PDF
    doc.build(elements)
    print(f"✓ Converted {md_file} → {pdf_file}")

def main():
    """Main function - converts all .md files in current directory"""
    # Install packages
    install_packages()

    # Get current working directory
    current_dir = os.getcwd()

    # Find all .md files in current directory
    md_files = []
    if len(sys.argv) > 1:
        # If files are specified as arguments, use those
        for md_file_arg in sys.argv[1:]:
            md_file = os.path.abspath(os.path.expanduser(md_file_arg))
            if os.path.exists(md_file):
                md_files.append(md_file)
            else:
                print(f"Warning: File not found: {md_file}")
    else:
        # Auto-discover all .md files in current directory
        for filename in os.listdir(current_dir):
            if filename.lower().endswith('.md'):
                md_file = os.path.join(current_dir, filename)
                md_files.append(md_file)

    if not md_files:
        print(f"No Markdown files found in: {current_dir}")
        print("\nUsage:")
        print("  python3 convert_md_to_pdf_simple.py              # Convert all .md files in current directory")
        print("  python3 convert_md_to_pdf_simple.py file.md      # Convert specific file(s)")
        sys.exit(0)

    print(f"Found {len(md_files)} Markdown file(s) to convert...\n")

    # Convert each markdown file
    success_count = 0
    error_count = 0

    for md_file in md_files:
        # Create PDF in same directory as MD file
        pdf_file = os.path.splitext(md_file)[0] + '.pdf'

        try:
            print(f"Converting: {os.path.basename(md_file)}")
            convert_md_to_pdf(md_file, pdf_file)
            print(f"✓ Created: {os.path.basename(pdf_file)}\n")
            success_count += 1
        except Exception as e:
            print(f"✗ Error converting {os.path.basename(md_file)}: {e}\n")
            import traceback
            traceback.print_exc()
            error_count += 1
            # Don't exit on error, continue with next file
            continue

    # Summary
    print(f"\n{'='*50}")
    print(f"Summary: {success_count} successful, {error_count} errors")
    print(f"{'='*50}")

if __name__ == "__main__":
    main()
