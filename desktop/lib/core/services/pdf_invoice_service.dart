import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

import '../models/invoice.dart';
import 'company_settings_service.dart';

class PdfInvoiceService {
  static final _currencyFormat = NumberFormat('#,##0', 'en_US');

  static Future<void> printInvoice(
    Invoice invoice, {
    CompanySettings? company,
    String? preparedBy,
  }) async {
    final pdf = await _buildInvoicePdf(invoice,
        company: company ?? const CompanySettings(), preparedBy: preparedBy);
    await Printing.layoutPdf(onLayout: (format) => pdf.save());
  }

  static Future<void> sharePdf(
    Invoice invoice, {
    CompanySettings? company,
    String? preparedBy,
  }) async {
    final pdf = await _buildInvoicePdf(invoice,
        company: company ?? const CompanySettings(), preparedBy: preparedBy);
    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'Invoice_${invoice.invoiceNumber}.pdf',
    );
  }

  static Future<pw.Document> _buildInvoicePdf(
    Invoice invoice, {
    required CompanySettings company,
    String? preparedBy,
  }) async {
    final pdf = pw.Document();

    // Logo loading is not supported in the web build
    pw.MemoryImage? logoImage;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // ── Header ─────────────────────────────────────────────────────
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Company info + logo
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      if (logoImage != null) ...[
                        pw.Container(
                          width: 64,
                          height: 64,
                          child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                        ),
                        pw.SizedBox(width: 14),
                      ],
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            company.companyName.toUpperCase(),
                            style: pw.TextStyle(
                              fontSize: 20,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.teal800,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          if (company.address.isNotEmpty)
                            pw.Text(company.address,
                                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                          if (company.phone.isNotEmpty)
                            pw.Text('Tel: ${company.phone}',
                                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                          if (company.email.isNotEmpty)
                            pw.Text('Email: ${company.email}',
                                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                          if (company.website.isNotEmpty)
                            pw.Text(company.website,
                                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                          if (company.taxId.isNotEmpty)
                            pw.Text('TIN: ${company.taxId}',
                                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                          if (company.registrationNumber.isNotEmpty)
                            pw.Text('Reg No: ${company.registrationNumber}',
                                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                        ],
                      ),
                    ],
                  ),
                  // Invoice meta
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.teal800,
                          borderRadius: pw.BorderRadius.circular(4),
                        ),
                        child: pw.Text(
                          'INVOICE',
                          style: pw.TextStyle(
                            fontSize: 20,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                          ),
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text('Invoice #: ${invoice.invoiceNumber}',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text('Date: ${DateFormat('MMMM d, yyyy').format(invoice.date)}'),
                      pw.Text('Due: ${DateFormat('MMMM d, yyyy').format(invoice.dueDate)}'),
                      if (company.defaultPaymentTerms.isNotEmpty)
                        pw.Text('Terms: ${company.defaultPaymentTerms}',
                            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                      pw.SizedBox(height: 4),
                      _buildPdfStatusBadge(invoice.status),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 24),

              // ── Bill To ────────────────────────────────────────────────────
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('BILL TO:',
                        style: pw.TextStyle(
                            fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600)),
                    pw.SizedBox(height: 4),
                    pw.Text(invoice.customerName ?? 'Customer',
                        style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Customer ID: ${invoice.customerId}',
                        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // ── Line Items Table ────────────────────────────────────────────
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                columnWidths: {
                  0: const pw.FlexColumnWidth(4),
                  1: const pw.FlexColumnWidth(1),
                  2: const pw.FlexColumnWidth(2),
                  3: const pw.FlexColumnWidth(2),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.teal800),
                    children: [
                      _tableHeaderCell('Description'),
                      _tableHeaderCell('Qty'),
                      _tableHeaderCell('Unit Price'),
                      _tableHeaderCell('Amount'),
                    ],
                  ),
                  ...invoice.lines.map((line) => pw.TableRow(
                        children: [
                          _tableCell(line.description),
                          _tableCell(line.quantity.toStringAsFixed(0),
                              align: pw.TextAlign.center),
                          _tableCell(
                              '${invoice.currencyCode} ${_currencyFormat.format(line.unitPrice)}',
                              align: pw.TextAlign.right),
                          _tableCell(
                              '${invoice.currencyCode} ${_currencyFormat.format(line.amount)}',
                              align: pw.TextAlign.right),
                        ],
                      )),
                  if (invoice.lines.isEmpty)
                    pw.TableRow(
                      children: [
                        _tableCell('No line items'),
                        _tableCell('-'),
                        _tableCell('-'),
                        _tableCell('-'),
                      ],
                    ),
                ],
              ),
              pw.SizedBox(height: 16),

              // ── Totals ─────────────────────────────────────────────────────
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Container(
                    width: 260,
                    child: pw.Column(
                      children: [
                        _totalRow('Subtotal', invoice.subtotal, invoice.currencyCode),
                        _totalRow('VAT (18%)', invoice.taxAmount, invoice.currencyCode),
                        pw.Divider(color: PdfColors.grey400),
                        _totalRow('Total', invoice.total, invoice.currencyCode,
                            isBold: true, fontSize: 13),
                        if (invoice.amountPaid > 0)
                          _totalRow('Amount Paid', invoice.amountPaid, invoice.currencyCode,
                              color: PdfColors.green),
                        if (invoice.balance > 0) ...[
                          pw.Divider(color: PdfColors.grey400),
                          _totalRow('Balance Due', invoice.balance, invoice.currencyCode,
                              isBold: true, color: PdfColors.red, fontSize: 13),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 20),

              // ── Notes ──────────────────────────────────────────────────────
              if (invoice.notes != null && invoice.notes!.isNotEmpty) ...[
                pw.Text('Notes:',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                pw.SizedBox(height: 4),
                pw.Text(invoice.notes!,
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                pw.SizedBox(height: 12),
              ],

              // ── Terms ──────────────────────────────────────────────────────
              if (invoice.terms != null && invoice.terms!.isNotEmpty) ...[
                pw.Text('Terms & Conditions:',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                pw.SizedBox(height: 4),
                pw.Text(invoice.terms!,
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                pw.SizedBox(height: 12),
              ] else if (company.defaultTerms != null && company.defaultTerms!.isNotEmpty) ...[
                pw.Text('Terms & Conditions:',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                pw.SizedBox(height: 4),
                pw.Text(company.defaultTerms!,
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                pw.SizedBox(height: 12),
              ],

              pw.Spacer(),

              // ── Signature / Prepared By ────────────────────────────────────
              if (preparedBy != null && preparedBy.isNotEmpty) ...[
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(vertical: 12),
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300)),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Prepared by:',
                              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                          pw.SizedBox(height: 2),
                          pw.Text(preparedBy,
                              style:
                                  pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Container(
                            width: 140,
                            child: pw.Divider(color: PdfColors.grey500),
                          ),
                          pw.Text('Authorised Signature',
                              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],

              // ── Footer ─────────────────────────────────────────────────────
              pw.Container(
                padding: const pw.EdgeInsets.only(top: 8),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                        '${company.companyName} — Thank you for your business',
                        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
                    pw.Text(
                        'Generated ${DateFormat('MMM d, yyyy').format(DateTime.now())}',
                        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf;
  }

  static pw.Widget _buildPdfStatusBadge(InvoiceStatus status) {
    PdfColor color;
    String label;
    switch (status) {
      case InvoiceStatus.paid:
        color = PdfColors.green;
        label = 'PAID';
        break;
      case InvoiceStatus.partial:
        color = PdfColors.blue;
        label = 'PARTIAL';
        break;
      case InvoiceStatus.pending:
        color = PdfColors.orange;
        label = 'PENDING';
        break;
      case InvoiceStatus.overdue:
        color = PdfColors.red;
        label = 'OVERDUE';
        break;
      case InvoiceStatus.draft:
        color = PdfColors.grey;
        label = 'DRAFT';
        break;
      case InvoiceStatus.sent:
        color = PdfColors.teal;
        label = 'SENT';
        break;
      case InvoiceStatus.cancelled:
        color = PdfColors.grey;
        label = 'CANCELLED';
        break;
    }

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: pw.BoxDecoration(
        color: color,
        borderRadius: pw.BorderRadius.circular(3),
      ),
      child: pw.Text(label,
          style: pw.TextStyle(
              fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
    );
  }

  static pw.Widget _tableHeaderCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(text,
          style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10)),
    );
  }

  static pw.Widget _tableCell(String text,
      {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(text,
          style: const pw.TextStyle(fontSize: 10), textAlign: align),
    );
  }

  static pw.Widget _totalRow(
    String label,
    double amount,
    String currency, {
    bool isBold = false,
    double fontSize = 10,
    PdfColor? color,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label,
              style: pw.TextStyle(
                  fontSize: fontSize,
                  fontWeight: isBold ? pw.FontWeight.bold : null)),
          pw.Text(
            '$currency ${_currencyFormat.format(amount)}',
            style: pw.TextStyle(
                fontSize: fontSize,
                fontWeight: isBold ? pw.FontWeight.bold : null,
                color: color),
          ),
        ],
      ),
    );
  }
}
