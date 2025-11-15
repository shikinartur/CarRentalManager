import 'package:flutter/material.dart';

class ResponsiveWrapper extends StatelessWidget {
  final Widget child;
  
  const ResponsiveWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Определяем тип устройства по ширине экрана
        if (constraints.maxWidth > 1200) {
          // Desktop - ограничиваем ширину и центрируем
          return Scaffold(
            body: Center(
              child: Container(
                width: 400, // Мобильная ширина для десктопа
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: child,
              ),
            ),
          );
        } else if (constraints.maxWidth > 800) {
          // Tablet - средняя ширина
          return Scaffold(
            body: Center(
              child: Container(
                width: 500,
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: child,
              ),
            ),
          );
        } else {
          // Mobile - полная ширина
          return child;
        }
      },
    );
  }
}