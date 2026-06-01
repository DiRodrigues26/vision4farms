import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

void safeBack(BuildContext context, {String fallback = '/home'}) {
  if (Navigator.of(context).canPop()) {
    Navigator.of(context).pop();
  } else if (GoRouter.of(context).canPop()) {
    GoRouter.of(context).pop();
  } else {
    GoRouter.of(context).go(fallback);
  }
}
