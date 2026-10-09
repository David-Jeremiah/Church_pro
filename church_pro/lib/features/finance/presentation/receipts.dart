import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../app/providers.dart';
import '../../../core/utils/formatters.dart';
import '../domain/finance_models.dart';

// ── Amount in words (English), for official receipts ──────────────────────
const _ones = [
  '', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine', 'ten', 'eleven', 'twelve',
  'thirteen', 'fourteen', 'fifteen', 'sixteen', 'seventeen', 'eighteen', 'nineteen',
];
const _tens = ['', '', 'twenty', 'thirty', 'forty', 'fifty', 'sixty', 'seventy', 'eighty', 'ninety'];

String _below100(int n) => n < 20 ? _ones[n] : _tens[n ~/ 10] + (n % 10 == 0 ? '' : '-${_ones[n % 10]}');

String _below1000(int n) {
  if (n < 100) return _below100(n);
  final rest = n % 100;
  return '${_ones[n ~/ 100]} hundred${rest == 0 ? '' : ' and ${_below100(rest)}'}';
}

String numberToWords(int n) {
  if (n == 0) return 'zero';
  var rest = n;
  final parts = <String>[];
  for (final (value, name) in [(1000000000, 'billion'), (1000000, 'million'), (1000, 'thousand')]) {
    if (rest >= value) {
      parts.add('${_below1000(rest ~/ value)} $name');
      rest %= value;
    }
  }
  if (rest > 0) parts.add(_below1000(rest));
  return parts.join(' ');
}

String amountInWords(int n, String currency) {
  final words = numberToWords(n);
  return '${words[0].toUpperCase()}${words.substring(1)} $currency only';
}

// ── PDF builders ──────────────────────────────────────────────────────────
Future<Uint8List> buildReceiptPdf({
  required String churchName,
  required String currency,
  required FinanceTransaction t,
  required String receiptNo,
}) async {
  final doc = pw.Document();
  final green = PdfColor.fromInt(0xFF0A3D33);
  final gold = PdfColor.fromInt(0xFFE6B422);

  pw.Widget field(String label, String value, {bool bold = false}) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 4),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(width: 105, child: pw.Text(label, style: pw.TextStyle(color: PdfColors.grey700, fontSize: 10))),
        pw.Expanded(
          child: pw.Text(
            value,
            style: pw.TextStyle(fontSize: 12, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal),
          ),
        ),
      ],
    ),
  );

  final purpose = [
    '${t.categoryName} (${t.fundName})',
    if (t.serviceTitle != null) 'at ${t.serviceTitle}',
  ].join(' ');

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a5.landscape,
      margin: const pw.EdgeInsets.all(30),
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(churchName, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: green)),
              pw.Text('OFFICIAL RECEIPT',
                  style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Container(height: 3, color: gold),
          pw.SizedBox(height: 14),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Receipt No: $receiptNo', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
              pw.Text('Date: ${formatDate(t.date)}', style: const pw.TextStyle(fontSize: 12)),
            ],
          ),
          pw.SizedBox(height: 14),
          field('Received from', t.memberName ?? 'Anonymous donor', bold: true),
          field('Amount', formatMoney(t.amount, currency: currency), bold: true),
          field('In words', amountInWords(t.amount, currency)),
          field('Being', purpose),
          field('Payment method', t.method.label),
          if (t.description.isNotEmpty) field('Notes', t.description),
          pw.Spacer(),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(width: 160, height: 1, color: PdfColors.grey600),
                  pw.SizedBox(height: 3),
                  pw.Text('Received by (signature)', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                ],
              ),
              pw.Text('Thank you for your faithful giving.',
                  style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic, color: green)),
            ],
          ),
        ],
      ),
    ),
  );
  return doc.save();
}

Future<Uint8List> buildStatementPdf({
  required String churchName,
  required String currency,
  required String memberName,
  required int year,
  required List<FinanceTransaction> entries,
}) async {
  final doc = pw.Document();
  final green = PdfColor.fromInt(0xFF0A3D33);
  final gold = PdfColor.fromInt(0xFFE6B422);
  final total = entries.fold<int>(0, (s, e) => s + e.amount);
  final byCategory = <String, int>{};
  for (final e in entries) {
    byCategory[e.categoryName] = (byCategory[e.categoryName] ?? 0) + e.amount;
  }
  final sorted = [...entries]..sort((a, b) => a.date.compareTo(b.date));

  pw.Widget cell(String text, {bool bold = false, bool right = false}) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 4),
    child: pw.Align(
      alignment: right ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
      child: pw.Text(text,
          style: pw.TextStyle(fontSize: 10, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
    ),
  );

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      build: (_) => [
        pw.Text(churchName, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: green)),
        pw.SizedBox(height: 6),
        pw.Container(height: 3, color: gold),
        pw.SizedBox(height: 16),
        pw.Text('Giving statement $year', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Text('Prepared for $memberName', style: const pw.TextStyle(fontSize: 11)),
        pw.SizedBox(height: 16),
        pw.Table(
          border: pw.TableBorder(horizontalInside: pw.BorderSide(color: PdfColors.grey300)),
          columnWidths: {0: const pw.FlexColumnWidth(3), 1: const pw.FlexColumnWidth(2)},
          children: [
            for (final e in byCategory.entries)
              pw.TableRow(children: [cell(e.key), cell(formatMoney(e.value, currency: currency), right: true)]),
            pw.TableRow(children: [
              cell('Total given in $year', bold: true),
              cell(formatMoney(total, currency: currency), bold: true, right: true),
            ]),
          ],
        ),
        pw.SizedBox(height: 20),
        pw.Text('Gifts', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        pw.Table(
          border: pw.TableBorder(horizontalInside: pw.BorderSide(color: PdfColors.grey300)),
          columnWidths: {
            0: const pw.FlexColumnWidth(2),
            1: const pw.FlexColumnWidth(3),
            2: const pw.FlexColumnWidth(2),
            3: const pw.FlexColumnWidth(2),
            4: const pw.FlexColumnWidth(2),
          },
          children: [
            pw.TableRow(children: [
              cell('Date', bold: true),
              cell('Category', bold: true),
              cell('Method', bold: true),
              cell('Receipt', bold: true),
              cell('Amount', bold: true, right: true),
            ]),
            for (final e in sorted)
              pw.TableRow(children: [
                cell(formatDate(e.date)),
                cell(e.categoryName),
                cell(e.method.label),
                cell(e.receiptNo ?? '-'),
                cell(formatMoney(e.amount, currency: currency), right: true),
              ]),
          ],
        ),
        pw.SizedBox(height: 24),
        pw.Text('Thank you for your faithful giving.',
            style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic, color: green)),
      ],
    ),
  );
  return doc.save();
}
// ── Preview screen (print, save or share from here) ───────────────────────
class PdfPreviewScreen extends StatelessWidget {
  const PdfPreviewScreen({super.key, required this.title, required this.fileName, required this.buildPdf});

  final String title;
  final String fileName;
  final Future<Uint8List> Function() buildPdf;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: PdfPreview(
      build: (_) => buildPdf(),
      pdfFileName: '$fileName.pdf',
      canChangeOrientation: false,
      canChangePageFormat: false,
      canDebug: false,
    ),
  );
}

/// Issues the official receipt if it has none yet, then opens it.
Future<void> openReceipt(BuildContext context, WidgetRef ref, FinanceTransaction t) async {
  final churchId = ref.read(activeChurchIdProvider)!;
  final churchName = ref.read(churchProvider).value?.name ?? '';
  final currency = ref.read(currencyProvider);

  final number = t.receiptNo ?? await ref.read(financeRepositoryProvider).issueReceipt(churchId, t);
  if (!context.mounted) return;
  final issued = FinanceTransaction(
    id: t.id,
    type: t.type,
    amount: t.amount,
    fundId: t.fundId,
    fundName: t.fundName,
    categoryId: t.categoryId,
    categoryName: t.categoryName,
    method: t.method,
    date: t.date,
    description: t.description,
    memberId: t.memberId,
    memberName: t.memberName,
    serviceId: t.serviceId,
    serviceTitle: t.serviceTitle,
    receiptNo: number,
  );
  await Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (_) => PdfPreviewScreen(
      title: 'Receipt $number',
      fileName: 'receipt-$number',
      buildPdf: () => buildReceiptPdf(churchName: churchName, currency: currency, t: issued, receiptNo: number),
    ),
  ));
}

void openStatement(
    BuildContext context,
    WidgetRef ref, {
      required String memberName,
      required int year,
      required List<FinanceTransaction> entries,
    }) {
  final churchName = ref.read(churchProvider).value?.name ?? '';
  final currency = ref.read(currencyProvider);
  Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (_) => PdfPreviewScreen(
      title: 'Giving statement $year',
      fileName: 'statement-$year-${memberName.replaceAll(' ', '-')}',
      buildPdf: () => buildStatementPdf(
        churchName: churchName,
        currency: currency,
        memberName: memberName,
        year: year,
        entries: entries,
      ),
    ),
  ));
}