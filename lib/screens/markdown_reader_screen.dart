import 'dart:async';
import 'package:flutter/material.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class MarkdownHomePage extends StatefulWidget {
  final String markdownUrl;
  final String lessonTitle;
  const MarkdownHomePage({
    super.key,
    required this.markdownUrl,
    required this.lessonTitle,
  });

  @override
  State<MarkdownHomePage> createState() => _MarkdownHomePageState();
}

class _MarkdownHomePageState extends State<MarkdownHomePage> {
  String _mdContent = '';
  final TocController _tocController = TocController();
  bool _isLoading = true;
  String? _error;
  
  @override
  void initState() {
    super.initState();
    _loadMarkdown();
  }

  Future<void> _loadMarkdown() async {
    try {
      final file = await DefaultCacheManager().getSingleFile(widget.markdownUrl);
      final content = await file.readAsString();
      setState(() {
        _mdContent = content;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Не удалось загрузить документ';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _tocController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        
        title: Text(widget.lessonTitle),
        centerTitle: false,
        automaticallyImplyLeading: true,
      ),

      // Боковая панель с оглавлением
      drawer: Drawer(
        // shape: const RoundedRectangleBorder(
        //   borderRadius: BorderRadius.horizontal(right: Radius.circular(24)),
        // ),
        // width: 320,
        child: SafeArea(child:  _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _mdContent.isNotEmpty
                ? TocWidget(controller: _tocController)
                : const Center(child: Text('Оглавление недоступно')),
        ),
      ),

      // Основное содержимое с правильными отступами
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!))
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    // 16 dp — стандарт Material Design 3 для мобильных
                    // При необходимости: EdgeInsets.fromLTRB(16, 0, 16, 24)
                    child: MarkdownWidget(
                      data: _mdContent,
                      tocController: _tocController,
                      shrinkWrap: true,
                      physics: const BouncingScrollPhysics(),
                      // Опционально: улучшение читаемости
                      config: MarkdownConfig(configs: [
                        PConfig(textStyle: const TextStyle(height: 1.6, fontSize: 16)),
                        const TableConfig(
                          // wrapper: Card.new,
                          // tablePadding: EdgeInsets.all(12),
                        ),
                      ]),
                    ),
                  ),
      ),
      
    );
  }
}