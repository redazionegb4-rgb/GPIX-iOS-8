import 'dart:async';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import '../core/store.dart';
import '../ui/kit.dart';
import '../ui/entrance.dart';
import 'features13.dart';

class Welcome extends StatefulWidget {
  const Welcome({super.key});
  @override
  State<Welcome> createState() => _WelcomeState();
}

class _WelcomeState extends State<Welcome> {
  final formKey = GlobalKey<FormState>();
  final name = TextEditingController(),
      username = TextEditingController(),
      email = TextEditingController(),
      login = TextEditingController(),
      password = TextEditingController(),
      confirmation = TextEditingController();
  bool form = false,
      register = false,
      busy = false,
      showPassword = false,
      showConfirmation = false;
  String error = '';
  void switchForm(bool signUp) {
    if (busy) return;
    FocusScope.of(context).unfocus();
    formKey.currentState?.reset();
    setState(() {
      form = true;
      register = signUp;
      error = '';
      password.clear();
      confirmation.clear();
      showPassword = false;
      showConfirmation = false;
    });
  }

  Future<void> submit() async {
    if (busy || !(formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() {
      busy = true;
      error = '';
    });
    try {
      await GpixScope.of(context, listen: false).authenticate(
        login: register ? username.text : login.text,
        password: password.text,
        email: register ? email.text : null,
        name: register ? name.text : null,
      );
    } on http.ClientException {
      if (mounted)
        setState(
          () => error =
              'Non riusciamo a collegarci a GPIX. Controlla Internet e riprova.',
        );
    } on SocketException {
      if (mounted)
        setState(
          () => error = 'Connessione assente. Controlla Internet e riprova.',
        );
    } on TimeoutException {
      if (mounted)
        setState(
          () => error =
              'GPIX sta impiegando troppo tempo a rispondere. Riprova tra poco.',
        );
    } catch (e) {
      if (mounted)
        setState(
          () => error = e
              .toString()
              .replaceFirst('Exception: ', '')
              .replaceAll(
                'Il server non ha restituito una risposta valida.',
                'GPIX è temporaneamente non disponibile. Riprova tra poco.',
              ),
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> demo() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = '';
    });
    try {
      await GpixScope.of(context, listen: false).startDemo();
    } catch (_) {
      if (mounted)
        setState(
          () => error = 'Non è stato possibile aprire la demo. Riprova.',
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    for (final c in [name, username, email, login, password, confirmation]) {
      c.dispose();
    }
    super.dispose();
  }

  Widget input(
    TextEditingController controller,
    String label, {
    String? hint,
    IconData? icon,
    TextInputType keyboard = TextInputType.text,
    bool secret = false,
    bool confirm = false,
    TextCapitalization capitalization = TextCapitalization.none,
    TextInputAction action = TextInputAction.next,
    List<String>? autofillHints,
    String? Function(String?)? validator,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextFormField(
      key: ValueKey(
        'auth-${confirm
            ? 'confirmation'
            : secret
            ? 'password'
            : label}',
      ),
      controller: controller,
      enabled: !busy,
      keyboardType: keyboard,
      textCapitalization: capitalization,
      textInputAction: action,
      autofillHints: autofillHints,
      autocorrect: !secret && keyboard == TextInputType.name,
      enableSuggestions: !secret,
      obscureText: secret && !(confirm ? showConfirmation : showPassword),
      onFieldSubmitted: action == TextInputAction.done ? (_) => submit() : null,
      validator: validator,
      style: TextStyle(color: foreground(context), fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        prefixIcon: icon == null ? null : GIcon(icon, size: 20, color: muted),
        suffixIcon: secret
            ? IconButton(
                tooltip: (confirm ? showConfirmation : showPassword)
                    ? 'Nascondi password'
                    : 'Mostra password',
                onPressed: busy
                    ? null
                    : () => setState(() {
                        if (confirm)
                          showConfirmation = !showConfirmation;
                        else
                          showPassword = !showPassword;
                      }),
                icon: GIcon(
                  (confirm ? showConfirmation : showPassword)
                      ? CupertinoIcons.eye_slash
                      : CupertinoIcons.eye,
                  size: 20,
                  color: muted,
                ),
              )
            : null,
        filled: true,
        fillColor: subdued(context),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 17,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Theme.of(context).dividerColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: auraBlue, width: 1.4),
        ),
        errorMaxLines: 2,
      ),
    ),
  );
  @override
  Widget build(BuildContext c) => Scaffold(
    body: SafeArea(
      child: LayoutBuilder(
        builder: (c, box) => SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(25, 16, 25, 25),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: (box.maxHeight - 41).clamp(0, double.infinity),
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: EntranceMotion(
                  stage: form ? (register ? 'register' : 'login') : 'welcome',
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Center(child: BrandLogo(width: form ? 160 : 235)),
                      const SizedBox(height: 20),
                      AuraPanel(
                        radius: 28,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 19,
                            vertical: 23,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (form)
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: IconButton(
                                    tooltip: 'Indietro',
                                    onPressed: busy
                                        ? null
                                        : () {
                                            FocusScope.of(c).unfocus();
                                            setState(() {
                                              form = false;
                                              error = '';
                                            });
                                          },
                                    icon: const GIcon(
                                      CupertinoIcons.chevron_left,
                                      size: 24,
                                    ),
                                  ),
                                ),
                              SizedBox(height: form ? 8 : 4),
                              if (!form) ...[
                                Text(
                                  'Il tuo mondo,\nin ogni sfumatura.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 34,
                                    height: 1.13,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -1.2,
                                    color: foreground(c),
                                  ),
                                ),
                                const SizedBox(height: 18),
                                const Text(
                                  'Storie da condividere. Persone da scoprire.\nUn posto dove essere te stesso.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: muted,
                                    fontSize: 15,
                                    height: 1.6,
                                  ),
                                ),
                                const SizedBox(height: 38),
                                PrimaryButton(
                                  'Accedi',
                                  onTap: busy ? null : () => switchForm(false),
                                ),
                                const SizedBox(height: 12),
                                PrimaryButton(
                                  'Crea un account',
                                  secondary: true,
                                  onTap: busy ? null : () => switchForm(true),
                                ),
                              ] else ...[
                                Text(
                                  register
                                      ? 'Crea il tuo account'
                                      : 'Bentornato su GPIX',
                                  style: TextStyle(
                                    fontSize: 27,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -.7,
                                    color: foreground(c),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  register
                                      ? 'Bastano pochi dati per iniziare a condividere.'
                                      : 'Accedi e ritrova le tue persone e le tue storie.',
                                  style: const TextStyle(
                                    color: muted,
                                    fontSize: 14,
                                    height: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 25),
                                AutofillGroup(
                                  child: Form(
                                    key: formKey,
                                    child: Column(
                                      children: [
                                        if (register) ...[
                                          input(
                                            name,
                                            'Nome',
                                            icon: CupertinoIcons.person,
                                            keyboard: TextInputType.name,
                                            capitalization:
                                                TextCapitalization.words,
                                            autofillHints: const [
                                              AutofillHints.name,
                                            ],
                                            validator: (v) =>
                                                (v ?? '').trim().isEmpty
                                                ? 'Inserisci il tuo nome'
                                                : (v ?? '').trim().length > 60
                                                ? 'Usa al massimo 60 caratteri'
                                                : null,
                                          ),
                                          input(
                                            username,
                                            'Nome utente',
                                            hint: 'es. nome.cognome',
                                            icon: CupertinoIcons.at,
                                            autofillHints: const [
                                              AutofillHints.newUsername,
                                            ],
                                            validator: (v) =>
                                                RegExp(
                                                  r'^[a-zA-Z0-9_.]{3,30}$',
                                                ).hasMatch((v ?? '').trim())
                                                ? null
                                                : 'Da 3 a 30 caratteri: lettere, numeri, punti o trattini bassi',
                                          ),
                                          input(
                                            email,
                                            'Email',
                                            icon: CupertinoIcons.mail,
                                            keyboard:
                                                TextInputType.emailAddress,
                                            autofillHints: const [
                                              AutofillHints.email,
                                            ],
                                            validator: (v) =>
                                                RegExp(
                                                  r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                                                ).hasMatch((v ?? '').trim())
                                                ? null
                                                : 'Inserisci un indirizzo email valido',
                                          ),
                                        ] else
                                          input(
                                            login,
                                            'Email o nome utente',
                                            icon: CupertinoIcons.person,
                                            autofillHints: const [
                                              AutofillHints.username,
                                            ],
                                            validator: (v) =>
                                                (v ?? '').trim().isEmpty
                                                ? 'Inserisci email o nome utente'
                                                : null,
                                          ),
                                        input(
                                          password,
                                          'Password',
                                          icon: CupertinoIcons.lock,
                                          secret: true,
                                          action: register
                                              ? TextInputAction.next
                                              : TextInputAction.done,
                                          autofillHints: register
                                              ? const [
                                                  AutofillHints.newPassword,
                                                ]
                                              : const [AutofillHints.password],
                                          validator: (v) {
                                            if ((v ?? '').isEmpty)
                                              return 'Inserisci la password';
                                            if (register &&
                                                (v ?? '').length < 10)
                                              return 'Usa almeno 10 caratteri';
                                            if ((v ?? '').length > 256)
                                              return 'Usa al massimo 256 caratteri';
                                            return null;
                                          },
                                        ),
                                        if (register)
                                          input(
                                            confirmation,
                                            'Conferma password',
                                            icon: CupertinoIcons.lock,
                                            secret: true,
                                            confirm: true,
                                            action: TextInputAction.done,
                                            autofillHints: const [
                                              AutofillHints.newPassword,
                                            ],
                                            validator: (v) => v != password.text
                                                ? 'Le password non coincidono'
                                                : null,
                                          ),
                                        if (register)
                                          const Padding(
                                            padding: EdgeInsets.only(
                                              bottom: 16,
                                            ),
                                            child: Align(
                                              alignment: Alignment.centerLeft,
                                              child: Text(
                                                'Scegli una password di almeno 10 caratteri.',
                                                style: TextStyle(
                                                  color: muted,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          ),
                                        if (error.isNotEmpty)
                                          Container(
                                            key: const ValueKey('auth-error'),
                                            width: double.infinity,
                                            margin: const EdgeInsets.only(
                                              bottom: 16,
                                            ),
                                            padding: const EdgeInsets.all(13),
                                            decoration: BoxDecoration(
                                              color: danger.withValues(
                                                alpha: .08,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Semantics(
                                              liveRegion: true,
                                              child: Text(
                                                error,
                                                style: const TextStyle(
                                                  color: danger,
                                                  fontSize: 13,
                                                  height: 1.4,
                                                ),
                                              ),
                                            ),
                                          ),
                                        PrimaryButton(
                                          register ? 'Crea account' : 'Accedi',
                                          busy: busy,
                                          onTap: submit,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 13),
                                TextButton(
                                  onPressed: busy
                                      ? null
                                      : () => switchForm(!register),
                                  child: Text(
                                    register
                                        ? 'Hai già un account? Accedi'
                                        : 'Non hai un account? Registrati',
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                              SizedBox(height: form ? 16 : 28),
                              Row(
                                children: [
                                  Expanded(
                                    child: Divider(
                                      color: Theme.of(c).dividerColor,
                                    ),
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 15,
                                    ),
                                    child: Text(
                                      'oppure',
                                      style: TextStyle(
                                        color: muted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Divider(
                                      color: Theme.of(c).dividerColor,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              if (form && !register)
                                TextButton(
                                  onPressed: busy
                                      ? null
                                      : () => open(
                                          c,
                                          const AccountSecurity(mode: 'forgot'),
                                        ),
                                  child: const Text('Password dimenticata?'),
                                ),
                              TextButton(
                                onPressed: busy ? null : demo,
                                child: const Text(
                                  'Esplora la demo',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                              const Text(
                                'Prova GPIX senza creare un account.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 12, color: muted),
                              ),
                              const SizedBox(height: 22),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
