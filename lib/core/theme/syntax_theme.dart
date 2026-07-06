import 'package:flutter/material.dart';

/// IntelliJ IDEA Darcula syntax colors for highlight.js class names.
final Map<String, TextStyle> ideaSyntaxTheme = {
  'root': const TextStyle(
    color: Color(0xFFA9B7C6),
    backgroundColor: Color(0x00000000),
    fontFamily: 'Consolas',
    fontSize: 12,
    height: 1.5,
  ),

  'keyword': const TextStyle(color: Color(0xFFCC7832)),
  'built_in': const TextStyle(color: Color(0xFFCC7832)),
  'type': const TextStyle(color: Color(0xFFCC7832)),
  'literal': const TextStyle(color: Color(0xFFCC7832)),
  'selector-tag': const TextStyle(color: Color(0xFFCC7832)),

  'string': const TextStyle(color: Color(0xFF6A8759)),
  'char': const TextStyle(color: Color(0xFF6A8759)),
  'regexp': const TextStyle(color: Color(0xFF6A8759)),
  'quote': const TextStyle(
    color: Color(0xFF808080),
    fontStyle: FontStyle.italic,
  ),

  'number': const TextStyle(color: Color(0xFF6897BB)),
  'symbol': const TextStyle(color: Color(0xFF6897BB)),

  'comment': const TextStyle(
    color: Color(0xFF808080),
    fontStyle: FontStyle.italic,
  ),

  'meta': const TextStyle(color: Color(0xFFBBB529)),
  'meta-keyword': const TextStyle(color: Color(0xFFBBB529)),
  'meta-string': const TextStyle(color: Color(0xFF6A8759)),

  'title': const TextStyle(color: Color(0xFFE8BF6A)),
  'title.class': const TextStyle(color: Color(0xFFE8BF6A)),
  'title.class_': const TextStyle(color: Color(0xFFE8BF6A)),
  'title.function': const TextStyle(color: Color(0xFFE8BF6A)),
  'title.function_': const TextStyle(color: Color(0xFFE8BF6A)),
  'class': const TextStyle(color: Color(0xFFE8BF6A)),
  'function': const TextStyle(color: Color(0xFFE8BF6A)),
  'name': const TextStyle(color: Color(0xFFE8BF6A)),
  'section': const TextStyle(color: Color(0xFFE8BF6A)),
  'tag': const TextStyle(color: Color(0xFFE8BF6A)),

  'attr': const TextStyle(color: Color(0xFF9876AA)),
  'attribute': const TextStyle(color: Color(0xFF9876AA)),
  'property': const TextStyle(color: Color(0xFF9876AA)),
  'selector-id': const TextStyle(color: Color(0xFF9876AA)),
  'selector-class': const TextStyle(color: Color(0xFF9876AA)),
  'template-variable': const TextStyle(color: Color(0xFF9876AA)),

  'params': const TextStyle(color: Color(0xFFA9B7C6)),
  'variable': const TextStyle(color: Color(0xFFA9B7C6)),
  'subst': const TextStyle(color: Color(0xFFA9B7C6)),
  'operator': const TextStyle(color: Color(0xFFA9B7C6)),
  'punctuation': const TextStyle(color: Color(0xFFA9B7C6)),

  'bullet': const TextStyle(color: Color(0xFFCC7832)),
  'link': const TextStyle(color: Color(0xFF6897BB)),
  'formula': const TextStyle(color: Color(0xFF6897BB)),
  'emphasis': const TextStyle(fontStyle: FontStyle.italic),
  'strong': const TextStyle(fontWeight: FontWeight.bold),
  'addition': const TextStyle(color: Color(0xFF6A8759)),
  'deletion': const TextStyle(color: Color(0xFFBC3F3C)),
};

const double ideaCodeLineHeight = 18.0;

const TextStyle ideaCodeTextStyle = TextStyle(
  fontFamily: 'Consolas',
  fontSize: 12,
  height: 1.5,
);
