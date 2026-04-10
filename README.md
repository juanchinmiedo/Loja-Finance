# Finanças Hub

> Internal financial dashboard for a beauty salon — tracks revenue, worker performance, and service profitability in real time.

## Stack
Flutter 3 · Dart 3 · Firebase (Firestore + Auth) · Provider · fl_chart · Material 3 · i18n (en / es / pt-BR)

## Features
- 🔐 Google Sign-In with Firebase Custom Claims RBAC (admin / worker roles)
- 📊 KPI cards — revenue, avg ticket, occupancy, bookings with period-over-period % change
- 📈 Adaptive chart — last 12 days / weeks / months / years based on selected period
- 🔀 Multi-series comparator — overlay workers or services on the same chart
- 👤 Worker profiles with individual KPIs and revenue trend
- 💰 Service profitability with material cost editor and margin tracking

## Structure
```
lib/
├── models/       period, kpi_data, worker_stats, service_stats
├── providers/    period_provider (ChangeNotifier)
├── services/     auth, finance, worker, cost (all Firestore)
├── screens/      home, login, workers, worker_detail, services
└── widgets/      revenue_chart, top_services_chart, kpi_card, period_selector
```

## Setup
```bash
flutter pub get
flutterfire configure --project=your-project-id
flutter run
```
> Requires Firebase Custom Claims set via Admin SDK or Cloud Functions.
