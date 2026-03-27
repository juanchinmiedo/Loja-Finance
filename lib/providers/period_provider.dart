// lib/providers/period_provider.dart

import 'package:flutter/foundation.dart';
import '../models/period.dart';

class PeriodProvider extends ChangeNotifier {
  Period _current = Period.thisMonth();

  Period get current => _current;

  void select(Period period) {
    _current = period;
    notifyListeners();
  }

  void selectWeek()  => select(Period.thisWeek());
  void selectMonth() => select(Period.thisMonth());
  void selectYear()  => select(Period.thisYear());

  void selectCustom(DateTime from, DateTime to) =>
      select(Period.custom(from, to));
}
