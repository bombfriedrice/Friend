import 'package:flutter/material.dart';
import 'package:friend_private/backend/api_requests/api/pinecone.dart';
import 'package:friend_private/pages/home/page.dart';
import 'package:friend_private/utils/backups.dart';
import 'package:friend_private/widgets/device_widget.dart';
import 'package:gradient_borders/box_borders/gradient_box_border.dart';

class ImportBackupPage extends StatefulWidget {
  const ImportBackupPage({super.key});

  @override
  State<ImportBackupPage> createState() => _ImportBackupPageState();
}

class _ImportBackupPageState extends State<ImportBackupPage> with SingleTickerProviderStateMixin {
  TextEditingController uidController = TextEditingController();
  TextEditingController passwordController = TextEditingController();

  bool passwordVisible = true;
  bool importLoading = false;
  late AnimationController _animationController;

  @override
  void initState() {
    _animationController = AnimationController(
      duration: const Duration(seconds: 1, milliseconds: 500),
      vsync: this,
    )..repeat(reverse: true);
    super.initState();
  }
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
          backgroundColor: Theme.of(context).colorScheme.primary,
          appBar: AppBar(
              backgroundColor: Theme.of(context).colorScheme.primary,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new),
                onPressed: () => Navigator.pop(context),
              )),
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ListView(
              children: [
                const DeviceAnimationWidget(),
                const SizedBox(height: 48),
                _getTextField(uidController, hintText: 'Previous User ID', hasSuffixIcon: false, obscureText: false),
                const SizedBox(height: 12),
                _getTextField(passwordController, hintText: 'Backups Password', obscureText: passwordVisible,
                    onVisibilityChanged: () {
                  setState(() {
                    passwordVisible = !passwordVisible;
                  });
                }),
                const SizedBox(height: 40),
                Center(
                  child: MaterialButton(
                    onPressed: importLoading ? null : _import,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: const BorderSide(color: Colors.deepPurple),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    color: Colors.deepPurple,
                    child: importLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ))
                        : const Text(
                            'Import',
                            style: TextStyle(color: Colors.white),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                importLoading
                    ? FadeTransition(
                        opacity: _animationController,
                        child: const Text(
                          'Wait, don\'t close the app ...',
                          textAlign: TextAlign.center,
                          style: TextStyle(decoration: TextDecoration.underline, fontSize: 16),
                        ),
                      )
                    : const SizedBox(height: 0),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  _import() async {
    if (importLoading) return;
    if (uidController.text.isEmpty || passwordController.text.isEmpty) return;
    if (uidController.text.length < 36) {
      _snackBar('Invalid User ID');
      return;
    }
    if (passwordController.text.length < 8) {
      _snackBar('Invalid Password');
      return;
    }
    FocusScope.of(context).unfocus();
    try {
      setState(() => importLoading = true);
      var memories = await retrieveBackup(uidController.text, passwordController.text);
      if (memories.isEmpty) {
        _snackBar('No Memories Found');
        setState(() => importLoading = false);
        return;
      }
      debugPrint('Memories Imported: ${memories.length}');
      // SharedPreferencesUtil().backupPassword = passwordController.text;
      // SharedPreferencesUtil().backupsEnabled = true;
      // SharedPreferencesUtil().lastBackupDate = DateTime.now().toIso8601String();
      var nonDiscarded = memories.where((element) => !element.discarded).toList();
      for (var i = 0; i < nonDiscarded.length; i++) {
        var memory = nonDiscarded[i];
        if (memory.structured.target == null || memory.discarded) continue;
        var f = getEmbeddingsFromInput(memory.structured.target.toString()).then((vector) {
          createPineconeVector(memory.id.toString(), vector);
        });
        if (i % 10 == 0) {
          await f; // "wait" for previous 10 requests to finish
          await Future.delayed(const Duration(seconds: 1));
          debugPrint('Processing Memory: $i');
        }
      }
      // 54d2c392-57f1-46dc-b944-02740a651f7b
      if (nonDiscarded.length % 10 != 0) await Future.delayed(const Duration(seconds: 2));

      _snackBar('${memories.length} Memories Imported Successfully   🎉', seconds: 2);
      await Future.delayed(const Duration(seconds: 2));
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (c) => const HomePageWrapper()));
    } catch (e) {
      _snackBar(e.toString().replaceAll('Exception:', '').trim());
      setState(() => importLoading = false);
      return;
    }
    setState(() => importLoading = false);
    // Test ID: d2234422-819d-491f-aaa6-174e4683d233
  }

  _snackBar(String content, {int seconds = 1}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(content),
      duration: Duration(seconds: seconds),
    ));
  }

  _getTextField(
    TextEditingController controller, {
    String hintText = '',
    bool obscureText = true,
    bool hasSuffixIcon = true,
    VoidCallback? onVisibilityChanged,
  }) {
    return Container(
      width: double.maxFinite,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      margin: const EdgeInsets.fromLTRB(18, 0, 18, 0),
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        border: GradientBoxBorder(
          gradient: LinearGradient(colors: [
            Color.fromARGB(127, 208, 208, 208),
            Color.fromARGB(127, 188, 99, 121),
            Color.fromARGB(127, 86, 101, 182),
            Color.fromARGB(127, 126, 190, 236)
          ]),
          width: 2,
        ),
        shape: BoxShape.rectangle,
      ),
      child: TextField(
        enabled: true,
        controller: controller,
        obscureText: obscureText,
        enableSuggestions: false,
        autocorrect: false,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
            labelText: hintText,
            labelStyle: const TextStyle(fontSize: 14.0, color: Colors.grey),
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            suffixIcon: hasSuffixIcon
                ? IconButton(
                    icon: Icon(
                      obscureText ? Icons.visibility_off : Icons.visibility,
                      color: Colors.grey.shade200,
                    ),
                    onPressed: onVisibilityChanged,
                  )
                : null),
        // maxLines: 8,
        // minLines: 1,
        // keyboardType: TextInputType.multiline,
        style: TextStyle(fontSize: 14.0, color: Colors.grey.shade200),
      ),
    );
  }
}
