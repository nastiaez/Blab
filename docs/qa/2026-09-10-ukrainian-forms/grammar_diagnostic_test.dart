import 'package:blab/features/chat/widgets/grammatical_form_chooser.dart';
import 'package:blab/shared/services/message_translator.dart';
import 'package:blab/shared/models/grammatical_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
void main() {
 const a=GrammaticalFormAlternatives(before:'Ти ',feminine:'ходила',masculine:'ходив',after:' вчора?',subjectName:'Alice',subjectIsViewer:false);
 testWidgets('selection should show confirmation then Change should reopen', (t) async {
  GrammaticalForm? selected;
  await t.pumpWidget(MaterialApp(home:Scaffold(body:StatefulBuilder(builder:(c,setState)=>GrammaticalFormChooser(alternatives:a,selectedForm:selected,onChange:(){},onSelected:(f) async {setState(()=>selected=f);})))));
  await t.tap(find.text('ходила')); await t.pumpAndSettle();
  expect(find.text('Change'),findsOneWidget,reason:'a successful selection should become confirmation');
  await t.tap(find.text('Change')); await t.pumpAndSettle();
  expect(find.text('ходив'),findsOneWidget);
 });
 testWidgets('externally selected confirmation can reopen', (t) async {
  await t.pumpWidget(MaterialApp(home:Scaffold(body:GrammaticalFormChooser(alternatives:a,selectedForm:GrammaticalForm.feminine,onChange:(){},onSelected:(f) async {}))));
  await t.tap(find.text('Change')); await t.pumpAndSettle();
  expect(find.text('ходив'),findsOneWidget);
 });
}
