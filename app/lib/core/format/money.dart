const minusSign = '−';
const _nbsp = ' ';

enum MoneyDisplay { plain, signed, absolute }

String _grouped(int units) {
  final digits = units.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

String _decimal(int absoluteCents, {required bool grouping}) {
  final units = absoluteCents ~/ 100;
  final fraction = (absoluteCents % 100).toString().padLeft(2, '0');
  return '${grouping ? _grouped(units) : units},$fraction';
}

String formatMoney(int? cents, {MoneyDisplay display = MoneyDisplay.plain}) {
  if (cents == null) return '';
  final formatted = '${_decimal(cents.abs(), grouping: true)}$_nbsp€';
  if (display == MoneyDisplay.absolute || cents == 0) return formatted;
  if (cents < 0) return '$minusSign$formatted';
  return display == MoneyDisplay.signed ? '+$formatted' : formatted;
}

String formatMoneyFigure(int cents, {bool currency = true}) {
  final absolute = cents.abs();
  final number = absolute % 100 == 0 ? _grouped(absolute ~/ 100) : _decimal(absolute, grouping: true);
  return '${cents < 0 ? minusSign : ''}$number${currency ? '$_nbsp€' : ''}';
}

String formatMoneyCompact(int cents) {
  final sign = cents < 0 ? minusSign : '';
  final absolute = cents.abs();
  if (absolute >= 100000) {
    final thousands = (absolute / 100000 * 10).round() / 10;
    final text = thousands == thousands.truncate()
        ? thousands.toInt().toString()
        : thousands.toStringAsFixed(1).replaceAll('.', ',');
    return '$sign$text${_nbsp}k€';
  }
  return '$sign${(absolute / 100).round()}$_nbsp€';
}

String formatCentsForInput(int? cents, {bool grouping = false}) {
  if (cents == null) return '';
  final sign = cents < 0 ? '-' : '';
  return '$sign${_decimal(cents.abs(), grouping: grouping)}';
}

final _groupedWithDots = RegExp(r'^\d{1,3}(\.\d{3})+$');
final _digits = RegExp(r'^\d+$');
final _fraction = RegExp(r'^\d{0,2}$');
final _ignored = RegExp('[\\s  €]');

int? parseMoneyInput(String? raw) {
  if (raw == null) return null;
  var text = raw.replaceAll(_ignored, '').replaceFirst(RegExp(r'^\+'), '');
  if (text.isEmpty) return null;

  var negative = false;
  if (text.startsWith('-') || text.startsWith(minusSign)) {
    negative = true;
    text = text.substring(1);
  }

  String integerPart;
  var fractionPart = '';
  if (text.contains(',')) {
    final pieces = text.split(',');
    if (pieces.length != 2) return null;
    if (pieces[0].contains('.') && !_groupedWithDots.hasMatch(pieces[0])) return null;
    integerPart = pieces[0].replaceAll('.', '');
    fractionPart = pieces[1];
  } else if (_groupedWithDots.hasMatch(text)) {
    integerPart = text.replaceAll('.', '');
  } else if (text.contains('.')) {
    final pieces = text.split('.');
    if (pieces.length != 2) return null;
    integerPart = pieces[0];
    fractionPart = pieces[1];
  } else {
    integerPart = text;
  }

  if (integerPart.isEmpty) integerPart = '0';
  if (!_digits.hasMatch(integerPart) || !_fraction.hasMatch(fractionPart)) return null;
  if (integerPart.length > 15) return null;

  final cents = int.parse(integerPart) * 100 + int.parse(fractionPart.padRight(2, '0'));
  return negative && cents != 0 ? -cents : cents;
}
