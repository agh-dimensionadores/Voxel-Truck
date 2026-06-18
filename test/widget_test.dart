import 'package:flutter_test/flutter_test.dart';
import 'package:voxel_truck/app.dart';

void main() {
  testWidgets('App loads home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const VoxelTruckApp());
    await tester.pumpAndSettle();

    expect(find.text('Camiones'), findsOneWidget);
    expect(find.text('Nuevo camión'), findsOneWidget);
  });
}
