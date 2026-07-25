import 'package:flutter_bloc/flutter_bloc.dart';

// الكيوبيت هنا يدير رقم الصفحة الحالية (0, 1, 2)
class HomeCubit extends Cubit<int> {
  HomeCubit() : super(0); // الصفحة الافتراضية هي 0 (لوحة التحكم)

  // دالة لتغيير الصفحة
  void setTab(int index) => emit(index);
}