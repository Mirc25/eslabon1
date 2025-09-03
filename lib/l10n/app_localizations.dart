import 'package:flutter/material.dart';

class AppLocalizations {
  const AppLocalizations();

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  String get globalChat => 'Chat Global';
  String get range => 'Alcance';
  String get sendMessage => 'Escribe un mensaje...';
  String get errorOccurred => 'Ha ocurrido un error.';
}

