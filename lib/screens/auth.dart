import 'dart:async';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import '../core/store.dart';
import '../core/data.dart';
import '../ui/kit.dart';
import '../ui/entrance.dart';
import 'features13.dart';

class Welcome extends StatefulWidget {
  const Welcome({super.key, this.addingAccount = false});
  final bool addingAccount;
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
  @override
  void initState() {
    super.initState();
    form = widget.addingAccount;
  }

  Future<bool> rememberAccess() async {
    if (!mounted) return false;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Salvare i dati di accesso?'),
            content: const Text(
              'Salva la password in modo protetto su questo dispositivo per accedere a GPIX con un tocco.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Non ora'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Salva accesso'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> savedAction(Future<void> Function() action) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await perform(context, action);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget savedProfiles(BuildContext c) {
    final store = GpixScope.of(c);
    return Column(
      children: [
        for (final account in store.savedAccounts)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: SavedAccountTile(
              account: account,
              onTap: busy
                  ? null
                  : () => savedAction(
                      () => store.useSavedAccount(account.str('id')),
                    ),
              trailing: PopupMenuButton<String>(
                enabled: !busy,
                tooltip: 'Opzioni profilo salvato',
                onSelected: (_) => savedAction(
                  () => store.removeSavedAccount(account.str('id')),
                ),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'remove',
                    child: Text('Rimuovi accesso salvato'),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

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
        remember: rememberAccess,
      );
      if (mounted && widget.addingAccount) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
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
  Widget build(BuildContext c) {
    final hasSavedAccounts = GpixScope.of(c).savedAccounts.isNotEmpty;
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (c, box) => SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: EntranceMotion(
                  stage: form
                      ? (register ? 'register74' : 'login74')
                      : 'welcome74',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          if (form)
                            IconButton(
                              tooltip: 'Indietro',
                              onPressed: busy
                                  ? null
                                  : () {
                                      FocusScope.of(c).unfocus();
                                      setState(() {
                                        if (widget.addingAccount) {
                                          Navigator.pop(c);
                                          return;
                                        }
                                        form = false;
                                        error = '';
                                      });
                                    },
                              icon: const GIcon(
                                CupertinoIcons.chevron_left,
                                size: 23,
                              ),
                            ),
                          const BrandLogo(width: 105),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: auraBlue.withValues(alpha: .09),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'Il tuo spazio.',
                              style: TextStyle(
                                color: auraBlue,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (!form) ...[
                        if (hasSavedAccounts) ...[
                          const SizedBox(height: 24),
                          Text(
                            'Scegli un profilo',
                            style: Theme.of(c).textTheme.headlineMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -.7,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tocca il tuo profilo per accedere.',
                            style: TextStyle(color: secondaryText(c)),
                          ),
                          const SizedBox(height: 22),
                          savedProfiles(c),
                          const SizedBox(height: 10),
                        ] else ...[
                          const SizedBox(height: 32),
                          const Center(child: _AuthArtwork()),
                          const SizedBox(height: 32),
                        ],
                        PrimaryButton(
                          hasSavedAccounts
                              ? 'Accedi con un altro account'
                              : 'Accedi',
                          onTap: busy ? null : () => switchForm(false),
                        ),
                        const SizedBox(height: 12),
                        PrimaryButton(
                          'Crea un account',
                          secondary: true,
                          onTap: () => switchForm(true),
                        ),
                      ] else ...[
                        const SizedBox(height: 30),
                        const BrandLogo(width: 104),
                        const SizedBox(height: 20),
                        Text(
                          register ? 'Crea un account' : 'Accedi a GPIX',
                          style: TextStyle(
                            color: foreground(c),
                            fontSize: 34,
                            height: 1.12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const SizedBox(height: 24),
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
                                    capitalization: TextCapitalization.words,
                                    autofillHints: const [AutofillHints.name],
                                    validator: (v) => (v ?? '').trim().isEmpty
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
                                    keyboard: TextInputType.emailAddress,
                                    autofillHints: const [AutofillHints.email],
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
                                    validator: (v) => (v ?? '').trim().isEmpty
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
                                      ? const [AutofillHints.newPassword]
                                      : const [AutofillHints.password],
                                  validator: (v) {
                                    if ((v ?? '').isEmpty)
                                      return 'Inserisci la password';
                                    if (register && (v ?? '').length < 10)
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
                                    padding: EdgeInsets.only(bottom: 16),
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
                                    margin: const EdgeInsets.only(bottom: 16),
                                    padding: const EdgeInsets.all(13),
                                    decoration: BoxDecoration(
                                      color: danger.withValues(alpha: .08),
                                      borderRadius: BorderRadius.circular(12),
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

                        if (!register)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: busy
                                  ? null
                                  : () => open(
                                      c,
                                      const AccountSecurity(mode: 'forgot'),
                                    ),
                              child: const Text('Password dimenticata?'),
                            ),
                          ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: Divider(color: Theme.of(c).dividerColor),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                              ),
                              child: Text(
                                'GPIX',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: secondaryText(c),
                                  letterSpacing: 2,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Divider(color: Theme.of(c).dividerColor),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: busy ? null : () => switchForm(!register),
                          child: Text(
                            register
                                ? 'Hai già un account? Accedi'
                                : 'Non hai un account? Registrati',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Finite reveal respects Reduce Motion and never runs a background ticker.
class _AuthArtwork extends StatelessWidget {
  const _AuthArtwork();

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: .92, end: 1),
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 280),
    curve: Curves.easeOutCubic,
    builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
    child: DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: GIcon(
          CupertinoIcons.camera,
          size: 44,
          color: foreground(context),
        ),
      ),
    ),
  );
}
