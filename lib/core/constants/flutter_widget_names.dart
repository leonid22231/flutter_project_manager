/// Known Flutter widget class names used to filter library widget usages.
abstract final class FlutterWidgetNames {
  static const knownWidgets = {
    'AboutDialog', 'AbsorbPointer', 'AlertDialog', 'Align', 'AnimatedAlign',
    'AnimatedBuilder', 'AnimatedContainer', 'AnimatedCrossFade', 'AnimatedList',
    'AnimatedOpacity', 'AnimatedPadding', 'AnimatedPhysicalModel',
    'AnimatedPositioned', 'AnimatedRotation', 'AnimatedScale', 'AnimatedSize',
    'AnimatedSlide', 'AnimatedSwitcher', 'AnimatedWidget', 'AppBar',
    'AspectRatio', 'Autocomplete', 'BackdropFilter', 'Banner', 'Baseline',
    'BlockSemantics', 'BottomAppBar', 'BottomNavigationBar', 'BottomSheet',
    'Builder', 'Card', 'Center', 'Checkbox', 'CheckboxListTile', 'Chip',
    'ChoiceChip', 'CircleAvatar', 'CircularProgressIndicator',
    'ClipOval', 'ClipPath', 'ClipRect', 'ClipRRect', 'ColoredBox', 'Column',
    'ConstrainedBox', 'Container', 'CupertinoActionSheet',
    'CupertinoActivityIndicator', 'CupertinoAlertDialog', 'CupertinoApp',
    'CupertinoButton', 'CupertinoContextMenu', 'CupertinoDatePicker',
    'CupertinoDialogAction', 'CupertinoFullscreenDialogTransition',
    'CupertinoNavigationBar', 'CupertinoPageScaffold', 'CupertinoPageTransition',
    'CupertinoPicker', 'CupertinoPopupSurface', 'CupertinoScrollbar',
    'CupertinoSearchTextField', 'CupertinoSegmentedControl',
    'CupertinoSlider', 'CupertinoSwitch', 'CupertinoTabBar',
    'CupertinoTabScaffold', 'CupertinoTabView', 'CupertinoTextField',
    'CustomPaint', 'CustomScrollView', 'DataTable', 'DataColumn', 'DataRow',
    'DatePickerDialog', 'DecoratedBox', 'DefaultTabController', 'Dialog',
    'Dismissible', 'Divider', 'Draggable', 'DraggableScrollableSheet',
    'DragTarget', 'Drawer', 'DropdownButton', 'DropdownMenu', 'ElevatedButton',
    'ExcludeSemantics', 'Expanded', 'FadeTransition', 'FilterChip',
    'FilledButton', 'FitWidth', 'Flexible', 'FlexibleSpaceBar',
    'FloatingActionButton', 'Flow', 'Focus', 'FocusScope', 'Form',
    'FormField', 'FractionallySizedBox', 'FutureBuilder', 'GestureDetector',
    'GridView', 'Hero', 'Icon', 'IconButton', 'IgnorePointer', 'Image',
    'IndexedStack', 'InkWell', 'InputChip', 'InteractiveViewer',
    'LayoutBuilder', 'LimitedBox', 'LinearProgressIndicator', 'ListBody',
    'ListTile', 'ListView', 'LongPressDraggable', 'Material', 'MaterialApp',
    'MaterialBanner', 'MaterialButton', 'MenuAnchor', 'MergeSemantics',
    'NavigationBar', 'NavigationDrawer', 'NavigationRail', 'NestedScrollView',
    'NotificationListener', 'Offstage', 'Opacity', 'OrientationBuilder',
    'OutlinedButton', 'OverflowBar', 'Padding', 'PageView', 'PhysicalModel',
    'PhysicalShape', 'Placeholder', 'PopupMenuButton', 'Positioned',
    'PreferredSize', 'Radio', 'RadioListTile', 'RangeSlider', 'RawChip',
    'RawGestureDetector', 'RawMaterialButton', 'RefreshIndicator',
    'ReorderableListView', 'RepaintBoundary', 'RichText', 'RotatedBox',
    'Row', 'SafeArea', 'Scaffold', 'ScaleTransition', 'Scrollable',
    'Scrollbar', 'SelectableText', 'Semantics', 'ShaderMask', 'SimpleDialog',
    'SingleChildScrollView', 'SizedBox', 'SlideTransition', 'Slider',
    'SliverAppBar', 'SliverFillRemaining', 'SliverFixedExtentList',
    'SliverGrid', 'SliverList', 'SliverOpacity', 'SliverPadding',
    'SliverToBoxAdapter', 'SliverVisibility', 'SnackBar', 'Spacer',
    'Stack', 'StatefulBuilder', 'StatelessWidget', 'StatefulWidget',
    'Stepper', 'StreamBuilder', 'Switch', 'SwitchListTile', 'SystemMouseRegion',
    'Tab', 'TabBar', 'TabBarView', 'Table', 'Text', 'TextButton',
    'TextField', 'TextFormField', 'TimePickerDialog', 'Tooltip',
    'Transform', 'UnconstrainedBox', 'UserAccountsDrawerHeader',
    'ValueListenableBuilder', 'VerticalDivider', 'Visibility',
    'WidgetSpan', 'WillPopScope', 'Wrap',
  };

  static const nonWidgetTypes = {
    'Size', 'Offset', 'Rect', 'Radius', 'Color', 'Colors', 'ThemeData',
    'Theme', 'TextStyle', 'TextSpan', 'StrutStyle', 'BoxDecoration',
    'BoxConstraints', 'BoxShadow', 'EdgeInsets', 'EdgeInsetsGeometry',
    'BorderRadius', 'Border', 'BorderSide', 'OutlineInputBorder',
    'RoundedRectangleBorder', 'Gradient', 'LinearGradient', 'RadialGradient',
    'SweepGradient', 'Alignment', 'AlignmentGeometry', 'FractionalOffset',
    'Matrix4', 'Vector3', 'Vector4', 'Locale', 'PlatformException',
    'IOException', 'Exception', 'Error', 'ArgumentError', 'StateError',
    'FormatException', 'UnimplementedError', 'Request', 'Response',
    'REQUEST', 'GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'HEAD', 'OPTIONS',
    'Headers', 'MultipartFile', 'FormData', 'Uint8List', 'ByteData',
    'WidgetsFlutterBinding', 'PaintingBinding', 'SchedulerBinding',
    'MaterialColor', 'MaterialAccentColor', 'IconData', 'FontWeight',
    'FontStyle', 'TextAlign', 'TextDirection', 'TextOverflow', 'Clip',
    'BlendMode', 'FilterQuality', 'Brightness', 'MainAxisAlignment',
    'CrossAxisAlignment', 'MainAxisSize', 'VerticalDirection', 'Axis',
    'Curves', 'Curve', 'Tween', 'Animation', 'AnimationController',
    'FocusNode', 'ScrollController', 'TextEditingController', 'GlobalKey',
    'UniqueKey', 'ValueKey', 'ObjectKey', 'Localizations',
    'Directionality', 'MediaQuery', 'MediaQueryData', 'Navigator',
    'Overlay', 'Route', 'MaterialPageRoute', 'PageRoute', 'SnackBarAction',
    'ButtonStyle', 'InputDecoration',
    'CircularIntervalList', 'Interval', 'Decoration', 'DecorationImage',
    'InputBorder', 'ShapeDecoration', 'SystemUiOverlayStyle',
  };

  static bool isLikelyWidgetCall(String name, Set<String> customWidgetNames) {
    if (customWidgetNames.contains(name)) return true;
    if (nonWidgetTypes.contains(name)) return false;
    if (name == name.toUpperCase()) return false;
    if (name.endsWith('State')) return false;
    if (name.endsWith('Data') && !knownWidgets.contains(name)) return false;
    if (name.endsWith('Style') && !knownWidgets.contains(name)) return false;
    if (name.endsWith('Decoration') && !knownWidgets.contains(name)) {
      return false;
    }
    if (name.endsWith('Exception') || name.endsWith('Error')) return false;
    return knownWidgets.contains(name);
  }
}
