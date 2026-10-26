import 'package:flutter_test/flutter_test.dart';

import 'package:carli/core/format/money.dart';

const nbsp = ' ';

void main() {
  group('formatMoney', () {
    test('formats cents as es-ES euros, grouping thousands always', () {
      expect(formatMoney(269500), '2.695,00$nbsp€');
      expect(formatMoney(4250), '42,50$nbsp€');
      expect(formatMoney(123456789), '1.234.567,89$nbsp€');
      expect(formatMoney(-175527), '${minusSign}1.755,27$nbsp€');
    });

    test('supports signed and absolute displays', () {
      expect(formatMoney(4500, display: MoneyDisplay.signed), '+45,00$nbsp€');
      expect(formatMoney(4500), '45,00$nbsp€');
      expect(formatMoney(0, display: MoneyDisplay.signed), '0,00$nbsp€');
      expect(formatMoney(-50000, display: MoneyDisplay.absolute), '500,00$nbsp€');
      expect(formatMoney(-4250, display: MoneyDisplay.signed), '${minusSign}42,50$nbsp€');
    });

    test('returns an empty string without a value', () {
      expect(formatMoney(null), '');
    });
  });

  test('formats compact amounts', () {
    expect(formatMoneyCompact(400000), '4${nbsp}k€');
    expect(formatMoneyCompact(150000), '1,5${nbsp}k€');
    expect(formatMoneyCompact(4250), '43$nbsp€');
    expect(formatMoneyCompact(-4250), '${minusSign}43$nbsp€');
  });

  test('formats figures without empty decimals', () {
    expect(formatMoneyFigure(14100, currency: false), '141');
    expect(formatMoneyFigure(15000), '150$nbsp€');
    expect(formatMoneyFigure(123456), '1.234,56$nbsp€');
  });

  group('parseMoneyInput', () {
    const accepted = {
      '42,50': 4250,
      '42,5': 4250,
      '42': 4200,
      '0,99': 99,
      ',5': 50,
      '1.234,56': 123456,
      '1.234': 123400,
      '12.345.678': 1234567800,
      '42.50': 4250,
      '42.5': 4250,
      ' 1 234,56 € ': 123456,
      '+12,00': 1200,
      '-12,30': -1230,
      '−12,30': -1230,
    };
    for (final MapEntry(key: raw, value: cents) in accepted.entries) {
      test('parses "$raw"', () => expect(parseMoneyInput(raw), cents));
    }

    for (final raw in ['', '   ', 'abc', '12,345', '1,2,3', '1.23.4', '12a', '1.2345,00']) {
      test('rejects "$raw"', () => expect(parseMoneyInput(raw), isNull));
    }

    test('works in integer cents', () {
      expect(parseMoneyInput('0,10')! + parseMoneyInput('0,20')!, 30);
      expect(parseMoneyInput('19,99'), 1999);
    });
  });

  test('formats cents for editing', () {
    expect(formatCentsForInput(123456), '1234,56');
    expect(formatCentsForInput(5), '0,05');
    expect(formatCentsForInput(-1230), '-12,30');
    expect(formatCentsForInput(null), '');
    expect(formatCentsForInput(123456, grouping: true), '1.234,56');
  });
}
