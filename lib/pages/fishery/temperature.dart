import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class Temperature extends StatefulWidget {
  final DateTime startDate;
  final DateTime endDate;

  const Temperature({Key? key, required this.startDate, required this.endDate}) : super(key: key);

  @override
  _TemperatureState createState() => _TemperatureState();
}

class _TemperatureState extends State<Temperature> {
  final List<FlSpot> temperatureData = const [
    FlSpot(0, 20),
    FlSpot(1, 22),
    FlSpot(2, 21),
    FlSpot(3, 23),
    FlSpot(4, 25),
    FlSpot(5, 24),
    FlSpot(6, 26),
  ];

  Widget bottomTitleWidgets(double value, TitleMeta meta) {
    const style = TextStyle(
      color: Colors.black54,
      fontWeight: FontWeight.bold,
      fontSize: 12,
    );

    String text;
    switch (value.toInt()) {
      case 0:
        text = 'Mon';
        break;
      case 1:
        text = 'Tue';
        break;
      case 2:
        text = 'Wed';
        break;
      case 3:
        text = 'Thu';
        break;
      case 4:
        text = 'Fri';
        break;
      default:
        return Container();
    }

    return Text(text, style: style);
  }

  Widget leftTitleWidgets(double value, TitleMeta meta) {
    const style = TextStyle(
      color: Colors.black54,
      fontWeight: FontWeight.bold,
      fontSize: 12,
    );

    if (value % 5 != 0) {
      return Container();
    }

    return Text(value.toInt().toString(), style: style);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Temperature Chart')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: LineChart(
          LineChartData(
            minX: 0,
            maxX: (temperatureData.length - 1).toDouble(),
            minY: 10,
            maxY: 30,
            lineBarsData: [
              LineChartBarData(
                spots: temperatureData,
                isCurved: true,
                barWidth: 3,
                color: Colors.blue,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(show: true, color: Colors.blue.withOpacity(0.3)),
              ),
            ],
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 32,
                  getTitlesWidget: bottomTitleWidgets,
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  getTitlesWidget: leftTitleWidgets,
                ),
              ),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            gridData: const FlGridData(show: true),
            borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey, width: 0.5)),
          ),
        ),
      ),
    );
  }
}