import 'package:flutter/material.dart';

class CommonColor {
 static Color backgroundColor(bool isDarkTheme)
      {return isDarkTheme ? const Color(0xFF0F1A13) : const Color(0xFFF4F7F1);}

static  Color panelColor(bool isDarkTheme)
      {return isDarkTheme ? Color.fromRGBO(25, 38, 29, 1) : Colors.white;}

static Color weatherCardColor(bool isDarkTheme)
      {return isDarkTheme ? const Color(0xFF243528) : const Color(0xFFEEF5E9);}

static Color primaryTextColor(bool isDarkTheme)
      {return isDarkTheme ? const Color(0xFFF4F7F1) : const Color(0xFF18341D);}

static Color secondaryTextColor(bool isDarkTheme)
      {return isDarkTheme ? const Color(0xFF9FB5A1) : Colors.grey;}

static Color cardAccent()
      {return const Color(0xFF49992E);}

static Color labelTextColor(bool isDarkTheme)
      {return isDarkTheme ? const Color(0xFFC4D3C5) : const Color(0xFF6C7570);}

static Color inputFillColor(bool isDarkTheme)
      {return isDarkTheme ? const Color(0xFF314437) : const Color(0xFFEEF5E9);}

}