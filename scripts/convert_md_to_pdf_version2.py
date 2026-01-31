#!/usr/bin/env python3
"""
Convert Markdown files to PDF
Requires: markdown, weasyprint
Version 2: Ignores lines 1 and 2 of the MD file when creating PDF
"""

import sys
import os
import subprocess
from pathlib import Path

def install_packages():
    """Install required packages if not available"""
    try:
        import markdown
        import weasyprint
        return True
    except ImportError:
        print("Installing required packages...")
        subprocess.check_call([
            sys.executable, "-m", "pip", "install",
            "--user", "--quiet", "markdown", "weasyprint"
        ])
        # Re-import after installation
        import importlib
        importlib.reload(sys.modules.get('markdown', None))
        return True

def convert_md_to_pdf(md_file, pdf_file):
    """Convert Markdown file to PDF (ignoring lines 1 and 2)"""
    import markdown
    from weasyprint import HTML, CSS

    # Read markdown file and skip first two lines
    with open(md_file, 'r', encoding='utf-8') as f:
        lines = f.readlines()
        # Skip lines 1 and 2 (index 0 and 1), keep the rest
        md_content = ''.join(lines[2:])

    # Convert markdown to HTML
    html_content = markdown.markdown(
        md_content,
        extensions=['tables', 'fenced_code', 'codehilite']
    )

    # Add CSS styling for better PDF appearance
    css_style = """
    <style>
        @page {
            size: A4;
            margin: 2cm;
        }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Helvetica, Arial, sans-serif;
            font-size: 11pt;
            line-height: 1.6;
            color: #333;
        }
        h1 {
            font-size: 24pt;
            margin-top: 1em;
            margin-bottom: 0.5em;
            border-bottom: 2px solid #333;
            padding-bottom: 0.3em;
        }
        h2 {
            font-size: 18pt;
            margin-top: 1.5em;
            margin-bottom: 0.5em;
            border-bottom: 1px solid #666;
            padding-bottom: 0.2em;
        }
        h3 {
            font-size: 14pt;
            margin-top: 1em;
            margin-bottom: 0.5em;
        }
        table {
            border-collapse: collapse;
            width: 100%;
            margin: 1em 0;
            font-size: 10pt;
        }
        table th, table td {
            border: 1px solid #ddd;
            padding: 8px;
            text-align: left;
        }
        table th {
            background-color: #f2f2f2;
            font-weight: bold;
        }
        code {
            background-color: #f4f4f4;
            padding: 2px 4px;
            border-radius: 3px;
            font-family: 'Courier New', monospace;
            font-size: 9pt;
        }
        pre {
            background-color: #f4f4f4;
            padding: 10px;
            border-radius: 5px;
            overflow-x: auto;
            font-size: 9pt;
        }
        pre code {
            background-color: transparent;
            padding: 0;
        }
        blockquote {
            border-left: 4px solid #ddd;
            margin: 1em 0;
            padding-left: 1em;
            color: #666;
        }
        ul, ol {
            margin: 0.5em 0;
            padding-left: 2em;
        }
        li {
            margin: 0.3em 0;
        }
        hr {
            border: none;
            border-top: 1px solid #ddd;
            margin: 2em 0;
        }
        strong {
            font-weight: bold;
        }
        em {
            font-style: italic;
        }
    </style>
    """

    # Wrap in full HTML document
    full_html = f"""
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="utf-8">
        <title>{Path(md_file).stem}</title>
        {css_style}
    </head>
    <body>
        {html_content}
    </body>
    </html>
    """

    # Convert HTML to PDF
    HTML(string=full_html).write_pdf(pdf_file)
    print(f"✓ Converted {md_file} → {pdf_file} (ignored first 2 lines)")

def main():
    """Main function - converts all .md files in the script's directory"""
    # Install packages
    install_packages()

    # Get the directory where the script is located
    script_dir = Path(__file__).parent.absolute()

    # Find all .md files in the script's directory
    md_files = list(script_dir.glob("*.md"))

    if not md_files:
        print(f"No .md files found in {script_dir}")
        sys.exit(0)

    print(f"Found {len(md_files)} Markdown file(s) in {script_dir}")
    print("-" * 50)

    # Convert each markdown file
    success_count = 0
    for md_file in md_files:
        pdf_file = md_file.with_suffix('.pdf')
        try:
            convert_md_to_pdf(str(md_file), str(pdf_file))
            success_count += 1
        except Exception as e:
            print(f"✗ Error converting {md_file.name}: {e}")

    print("-" * 50)
    print(f"Successfully converted {success_count}/{len(md_files)} file(s)")

if __name__ == "__main__":
    main()
