import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

import '../models/invoice.dart';

class PdfInvoiceService {
  static final _currencyFormat = NumberFormat('#,##0', 'en_US');

  static Future<void> printInvoice(Invoice invoice) async {
    final pdf = _buildInvoicePdf(invoice);
    await Printing.layoutPdf(onLayout: (format) => pdf.save());
  }

  static Future<void> sharePdf(Invoice invoice) async {
    final pdf = _buildInvoicePdf(invoice);
    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'Invoice_${invoice.invoiceNumber}.pdf',
    );
  }

  static pw.Document _buildInvoicePdf(Invoice invoice) {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'MAGIC BET LTD',
                        style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.teal800),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text('Plot 1, Kampala Road', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                      pw.Text('P.O. Box 12345, Kampala, Uganda', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                      pw.Text('Tel: +256 700 000 000', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                      pw.Text('Email: info@magicbet.ug', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                    ],
                  ),
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
                          style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text('Invoice #: ${invoice.invoiceNumber}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text('Date: ${DateFormat('MMMM d, yyyy').format(invoice.date)}'),
                      pw.Text('Due Date: ${DateFormat('MMMM d, yyyy').format(invoice.dueDate)}'),
                      pw.SizedBox(height: 4),
                      _buildPdfStatusBadge(invoice.status),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 30),

              // Bill To
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('BILL TO:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600)),
                    pw.SizedBox(height: 4),
                    pw.Text(invoice.customerName ?? 'Customer', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Customer ID: ${invoice.customerId}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Line Items Table
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                columnWidths: {
                  0: const pw.FlexColumnWidth(4),
                  1: const pw.FlexColumnWidth(1),
                  2: const pw.FlexColumnWidth(2),
                  3: const pw.FlexColumnWidth(2),
                },
                children: [
                  // Header
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.teal800),
                    children: [
                      _tableHeaderCell('Description'),
                      _tableHeaderCell('Qty'),
                      _tableHeaderCell('Unit Price'),
                      _tableHeaderCell('Amount'),
                    ],
                  ),
                  // Lines
                  ...invoice.lines.map((line) => pw.TableRow(
                        children: [
                          _tableCell(line.description),
                          _tableCell(line.quantity.toStringAsFixed(0), align: pw.TextAlign.center),
                          _tableCell('UGX ${_currencyFormat.format(line.unitPrice)}', align: pw.TextAlign.right),
                          _tableCell('UGX ${_currencyFormat.format(line.amount)}', align: pw.TextAlign.right),
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

              // Totals
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Container(
                    width: 250,
                    child: pw.Column(
                      children: [
                        _totalRow('Subtotal', invoice.subtotal),
                        _totalRow('VAT (18%)', invoice.taxAmount),
                        pw.Divider(color: PdfColors.grey400),
                        _totalRow('Total', invoice.total, isBold: true, fontSize: 14),
                        if (invoice.amountPaid > 0) _totalRow('Amount Paid', invoice.amountPaid, color: PdfColors.green),
                        if (invoice.balance > 0) ...[
                          pw.Divider(color: PdfColors.grey400),
                          _totalRow('Balance Due', invoice.balance, isBold: true, color: PdfColors.red, fontSize: 14),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 30),

              // Notes
              if (invoice.notes != null && invoice.notes!.isNotEmpty) ...[
                pw.Text('Notes:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                pw.SizedBox(height: 4),
                pw.Text(invoice.notes!, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                pw.SizedBox(height: 16),
              ],

              // Terms
              if (invoice.terms != null && invoice.terms!.isNotEmpty) ...[
                pw.Text('Terms & Conditions:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                pw.SizedBox(height: 4),
                pw.Text(invoice.terms!, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                pw.SizedBox(height: 16),
              ],

              pw.Spacer(),

              // Footer
              pw.Container(
                padding: const pw.EdgeInsets.only(top: 12),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Magic Bet Ltd - Thank you for your business', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500)),
                    pw.Text('Generated on ${DateFormat('MMMM d, yyyy').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500)),
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
      child: pw.Text(label, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
    );
  }

  static pw.Widget _tableHeaderCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(text, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10)),
    );
  }

  static pw.Widget _tableCell(String text, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(text, style: const pw.TextStyle(fontSize: 10), textAlign: align),
    );
  }

  static pw.Widget _totalRow(String label, double amount, {bool isBold = false, double fontSize = 10, PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: fontSize, fontWeight: isBold ? pw.FontWeight.bold : null)),
          pw.Text(
            'UGX ${_currencyFormat.format(amount)}',
            style: pw.TextStyle(fontSize: fontSize, fontWeight: isBold ? pw.FontWeight.bold : null, color: color),
          ),
        ],
      ),
    );
  }
}
