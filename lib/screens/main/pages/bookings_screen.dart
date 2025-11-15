import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.week;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  
  // Моковые данные для примера
  final List<Map<String, dynamic>> _cars = [
    {
      'id': '1',
      'brand': 'Toyota',
      'model': 'Camry',
      'year': '2023',
      'plate': 'А123БВ',
      'bookings': [
        {
          'client': 'Иванов И.И.',
          'startDate': DateTime.now().subtract(const Duration(days: 2)),
          'endDate': DateTime.now().add(const Duration(days: 3)),
          'status': 'Активная',
          'color': Colors.green,
        },
      ],
    },
    {
      'id': '2',
      'brand': 'BMW',
      'model': '5 Series',
      'year': '2022',
      'plate': 'В456ГД',
      'bookings': [
        {
          'client': 'Петров П.П.',
          'startDate': DateTime.now().add(const Duration(days: 1)),
          'endDate': DateTime.now().add(const Duration(days: 5)),
          'status': 'Забронирована',
          'color': Colors.blue,
        },
      ],
    },
    {
      'id': '3',
      'brand': 'Mercedes',
      'model': 'E-Class',
      'year': '2023',
      'plate': 'Е789ЖЗ',
      'bookings': [],
    },
    {
      'id': '4',
      'brand': 'Audi',
      'model': 'A6',
      'year': '2021',
      'plate': 'К012ЛМ',
      'bookings': [
        {
          'client': 'Сидоров С.С.',
          'startDate': DateTime.now().subtract(const Duration(days: 5)),
          'endDate': DateTime.now().subtract(const Duration(days: 1)),
          'status': 'Завершена',
          'color': Colors.grey,
        },
      ],
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Календарь
          Card(
            margin: const EdgeInsets.all(8.0),
            child: TableCalendar(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              calendarFormat: _calendarFormat,
              selectedDayPredicate: (day) {
                return isSameDay(_selectedDay, day);
              },
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              },
              onFormatChanged: (format) {
                setState(() {
                  _calendarFormat = format;
                });
              },
              onPageChanged: (focusedDay) {
                _focusedDay = focusedDay;
              },
              calendarStyle: CalendarStyle(
                selectedDecoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                todayDecoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
              ),
              headerStyle: const HeaderStyle(
                formatButtonVisible: true,
                titleCentered: true,
              ),
            ),
          ),
          
          // Заголовок списка автомобилей
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Автомобили и брони',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(
                  _selectedDay != null
                      ? 'На ${DateFormat('dd.MM.yyyy').format(_selectedDay!)}'
                      : 'Все брони',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey,
                      ),
                ),
              ],
            ),
          ),
          
          // Список автомобилей с бронированиями
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              itemCount: _cars.length,
              itemBuilder: (context, index) {
                final car = _cars[index];
                final bookings = (car['bookings'] as List).cast<Map<String, dynamic>>();
                
                // Фильтрация бронирований по выбранной дате
                final filteredBookings = _selectedDay != null
                    ? bookings.where((booking) {
                        final startDate = booking['startDate'] as DateTime;
                        final endDate = booking['endDate'] as DateTime;
                        return _selectedDay!.isAfter(startDate.subtract(const Duration(days: 1))) &&
                               _selectedDay!.isBefore(endDate.add(const Duration(days: 1)));
                      }).toList()
                    : bookings;
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 8.0),
                  child: ExpansionTile(
                    leading: const Icon(Icons.directions_car),
                    title: Text('${car['brand']} ${car['model']} ${car['year']}'),
                    subtitle: Text('ГРЗ: ${car['plate']}'),
                    trailing: filteredBookings.isEmpty
                        ? const Chip(
                            label: Text('Свободен'),
                            backgroundColor: Colors.green,
                            labelStyle: TextStyle(color: Colors.white),
                          )
                        : Chip(
                            label: Text('${filteredBookings.length} броней'),
                            backgroundColor: Colors.orange,
                            labelStyle: const TextStyle(color: Colors.white),
                          ),
                    children: [
                      if (filteredBookings.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text(
                            'Нет активных бронирований',
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      else
                        ...filteredBookings.map((booking) {
                          return ListTile(
                            leading: Icon(
                              Icons.person,
                              color: booking['color'],
                            ),
                            title: Text(booking['client']),
                            subtitle: Text(
                              '${DateFormat('dd.MM.yyyy').format(booking['startDate'])} - '
                              '${DateFormat('dd.MM.yyyy').format(booking['endDate'])}',
                            ),
                            trailing: Chip(
                              label: Text(booking['status']),
                              backgroundColor: booking['color'],
                              labelStyle: const TextStyle(color: Colors.white),
                            ),
                            onTap: () {
                              _showBookingDetails(context, car, booking);
                            },
                          );
                        }),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: ElevatedButton.icon(
                          onPressed: () {
                            _showNewBookingDialog(context, car);
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Создать бронь'),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _showNewBookingDialog(context, null);
        },
        icon: const Icon(Icons.add),
        label: const Text('Новая бронь'),
      ),
    );
  }

  void _showBookingDetails(BuildContext context, Map<String, dynamic> car, Map<String, dynamic> booking) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Детали брони - ${car['brand']} ${car['model']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Клиент: ${booking['client']}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Начало: ${DateFormat('dd.MM.yyyy HH:mm').format(booking['startDate'])}'),
            Text('Окончание: ${DateFormat('dd.MM.yyyy HH:mm').format(booking['endDate'])}'),
            const SizedBox(height: 8),
            Text('Статус: ${booking['status']}'),
            Text('ГРЗ: ${car['plate']}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Редактирование брони
            },
            child: const Text('Редактировать'),
          ),
        ],
      ),
    );
  }

  void _showNewBookingDialog(BuildContext context, Map<String, dynamic>? car) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(car != null 
            ? 'Новая бронь - ${car['brand']} ${car['model']}'
            : 'Новая бронь'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (car == null)
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Автомобиль'),
                items: _cars.map((c) {
                  return DropdownMenuItem<String>(
                    value: c['id'] as String,
                    child: Text('${c['brand']} ${c['model']} (${c['plate']})'),
                  );
                }).toList(),
                onChanged: (value) {},
              ),
            const SizedBox(height: 16),
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Имя клиента',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Дата начала',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.calendar_today),
              ),
              readOnly: true,
              onTap: () {
                // TODO: Показать Date Picker
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Дата окончания',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.calendar_today),
              ),
              readOnly: true,
              onTap: () {
                // TODO: Показать Date Picker
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Создание брони
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Бронь создана')),
              );
            },
            child: const Text('Создать'),
          ),
        ],
      ),
    );
  }
}
